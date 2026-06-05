import pandas as pd
from nltk.stem import WordNetLemmatizer
from rapidfuzz import process, fuzz
import nltk

# Download lemmatizer data
nltk.download("wordnet", quiet=True)

# === 1. Load file ===
file_path = "1. Summary of risks.xlsx"
df = pd.read_excel(file_path)

year_col = "Year"
risk_col = "Risk"
exclude_cols = ["Definition", "Likelihood"]
category_cols = [c for c in df.columns if c not in [year_col, risk_col] + exclude_cols]

# === 2. Reshape ===
long_df = df.melt(
    id_vars=[year_col, risk_col],
    value_vars=category_cols,
    var_name="Category",
    value_name="Flag"
)
long_df = long_df[long_df["Flag"] == 1]

# === 3. Text cleaning + abbreviation and plural/singular correction ===
lemmatizer = WordNetLemmatizer()

abbrev_map = {
    "natcat": "natural catastrophe",
    "infra": "infrastructure",
    "cii": "critical information infrastructure",
    "info": "information",
    "tech": "technology",
    "env": "environmental",
    "eco": "ecological",
    "geo": "geophysical",
    "gov": "government",
    "terror": "terrorist",
    "conf": "conflict",
    "disasters": "disaster",
    "diseases": "disease",
}

def expand_abbreviations(text):
    words = text.split()
    expanded = []
    for w in words:
        lw = w.lower().strip(".,:-_()")
        expanded.append(abbrev_map.get(lw, w))
    return " ".join(expanded)

def clean_text(s):
    s = str(s).strip().replace("\n", " ").replace("\r", " ")
    s = " ".join(s.split()).lower()
    s = expand_abbreviations(s)
    s = " ".join(lemmatizer.lemmatize(word) for word in s.split())
    return s

long_df["Risk_clean"] = long_df["Risk"].apply(clean_text)
long_df["Category_clean"] = long_df["Category"].apply(clean_text)

# === 4. Compute contiguous year ranges ===
def year_range(years):
    years = sorted(set(int(y) for y in years))
    if len(years) == 1:
        return str(years[0])
    ranges = []
    start = prev = years[0]
    for y in years[1:]:
        if y == prev + 1:
            prev = y
        else:
            ranges.append(f"{start}–{prev}" if start != prev else str(start))
            start = prev = y
    ranges.append(f"{start}–{prev}" if start != prev else str(start))
    return ", ".join(ranges)

# === 5. Aggregate by cleaned names ===
ranges_df = (
    long_df.groupby(["Risk_clean", "Category_clean"])[year_col]
    .apply(year_range)
    .reset_index(name="Range")
)

final_df = (
    ranges_df.groupby(["Risk_clean", "Category_clean"])["Range"]
    .apply(lambda x: "; ".join(sorted(set(x))))
    .reset_index(name="Year range")
)

# === 6. Restore readable names ===
original_names = long_df.drop_duplicates(["Risk_clean", "Category_clean"])[["Risk_clean", "Category_clean", "Risk", "Category"]]
final_df = final_df.merge(original_names, on=["Risk_clean", "Category_clean"], how="left")
final_df = final_df[["Risk", "Category", "Year range"]].sort_values(["Risk", "Category"]).reset_index(drop=True)

# === 7. Fuzzy merge very similar risk names ===
risk_names = final_df["Risk"].unique().tolist()
merge_map = {}
used = set()

for name in risk_names:
    if name in used:
        continue
    matches = process.extract(name, risk_names, scorer=fuzz.token_sort_ratio, limit=None)
    similar = [m[0] for m in matches if m[1] >= 90]  # adjust threshold if needed
    for s in similar:
        merge_map[s] = name
        used.add(s)

final_df["Unified Risk"] = final_df["Risk"].replace(merge_map)

# === 8. Merge by unified risk and category ===
fuzzy_df = (
    final_df.groupby(["Unified Risk", "Category"])["Year range"]
    .apply(lambda x: "; ".join(sorted(set(x))))
    .reset_index()
)

fuzzy_df = fuzzy_df.rename(columns={"Unified Risk": "Risk"})
fuzzy_df.to_excel("2. Unmerged risks.xlsx", index=False)

print("✅ Fuzzy-merged and fully cleaned table saved as '2. Unmerged risks.xlsx'")
print(fuzzy_df.head(10))
