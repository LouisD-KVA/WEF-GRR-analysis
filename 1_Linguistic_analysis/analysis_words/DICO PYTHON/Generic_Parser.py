"""
Program to provide generic parsing for all files in a user-specified directory.
The program assumes the input files have been scrubbed,
  i.e., HTML, ASCII-encoded binary, and any other embedded document structures that are not
  intended to be analyzed have been deleted from the file.

Dependencies:
    Python:  MOD_Load_MasterDictionary_vxxxx.py
    Data:    LoughranMcDonald_MasterDictionary_XXXX.csv

The program outputs:
   1.  File name
   2.  File size (in bytes)
   3.  Number of words (based on LM_MasterDictionary
   4.  Proportion of positive words (use with care - see LM, JAR 2016)
   5.  Proportion of negative words
   6.  Proportion of uncertainty words
   7.  Proportion of litigious words
   8.  Proportion of modal-strong words
   9.  Proportion of modal-weak words
  10.  Proportion of constraining words (see Bodnaruk, Loughran and McDonald, JFQA 2015)
  11.  Number of alphanumeric characters (a-z, A-Z)
  12.  Number of digits (0-9)
  13.  Number of numbers (collections of digits)
  14.  Average number of syllables
  15.  Average word length
  16.  Vocabulary (see Loughran-McDonald, JF, 2015)

  ND-SRAF
  McDonald 201606 : updated 201803; 202107; 202201
"""
# Importations de modules
import csv  # Pour la manipulation de fichiers CSV
import glob  # Pour la recherche de fichiers dans un répertoire
import re  # Pour les expressions régulières
import string  # Pour la manipulation de chaînes de caractères
import sys  # Pour les fonctionnalités système
import datetime as dt  # Pour la gestion des dates et heures
# Importation du script de chargement du dictionnaire principal
import MOD_Load_MasterDictionary_v2023 as LM

# Chemin d'accès au répertoire contenant les fichiers à analyser
TARGET_FILES = '/Users/melis/Desktop/UNHCR TXT/*.txt'


# Chemin d'accès au fichier CSV contenant le dictionnaire principal
MASTER_DICTIONARY_FILE = '/Users/melis/Desktop/Loughran-McDonald_MasterDictionary_1993-2023.csv'

# Chemin d'accès au fichier de sortie CSV
OUTPUT_FILE = '/Users/melis/Desktop/Parser.csv'

# Liste des noms de colonnes pour le fichier de sortie CSV
OUTPUT_FIELDS = ['file name', 'file size', 'number of words', '% negative', '% positive',
                 '% uncertainty', '% litigious', '% strong modal', '% weak modal',
                 '% constraining', '# of alphabetic', '# of digits',
                 '# of numbers', 'avg # of syllables per word', 'average word length', 'vocabulary']

# Chargement du dictionnaire principal à partir du fichier spécifié
lm_dictionary = LM.load_masterdictionary(
    MASTER_DICTIONARY_FILE, print_flag=True)

# Fonction principale


def main():
    # Ouverture du fichier de sortie en écriture
    f_out = open(OUTPUT_FILE, 'w')
    wr = csv.writer(f_out, lineterminator='\n')
    wr.writerow(OUTPUT_FIELDS)

    print("Chemin des fichiers à analyser :", TARGET_FILES)
    # Liste des fichiers dans le répertoire spécifié
    file_list = glob.glob(TARGET_FILES)
    print("Nombre de fichiers trouvés :", len(file_list))
    n_files = 0
    for file in file_list:
        n_files += 1
        print(f'{n_files:,} : {file}')
        with open(file, 'r', encoding='UTF-8', errors='ignore') as f_in:
            doc = f_in.read()
        # Prétraitements du document
        # Supprime toutes les références au mois de mai
        doc = re.sub('(May|MAY)', ' ', doc)
        doc = doc.upper()  # Convertit en majuscules pour faciliter l'analyse

        # Extraction des données à partir du document
        output_data = get_data(doc)
        output_data[0] = file
        output_data[1] = len(doc)
        wr.writerow(output_data)
        # if n_files == 3:
        # break

# Fonction pour extraire les données à partir du document


def get_data(doc):
    vdictionary = dict()
    _odata = [0] * 16
    total_syllables = 0
    word_length = 0

    # Séparation du document en tokens (mots)
    # Notez que \w+ divise les mots avec des tirets
    tokens = re.findall('\w+', doc)
    for token in tokens:
        # Exclusion des nombres et des mots inconnus
        if not token.isdigit() and len(token) > 1 and token in lm_dictionary:
            _odata[2] += 1  # Comptage des mots
            word_length += len(token)
            if token not in vdictionary:
                vdictionary[token] = 1
            # Extraction des attributs des mots à partir du dictionnaire principal
            # Cette ligne vérifie si le mot actuel a une valeur non nulle pour l'attribut "negative" dans le dictionnaire principal. Si c'est le cas, cela signifie que ce mot est associé à une connotation négative dans le dictionnaire. En conséquence, elle incrémente le compteur d'attribut négatif (_odata[3]) de 1.
            if lm_dictionary[token].negative:
                _odata[3] += 1
            if lm_dictionary[token].positive:
                _odata[4] += 1
            if lm_dictionary[token].uncertainty:
                _odata[5] += 1
            if lm_dictionary[token].litigious:
                _odata[6] += 1
            if lm_dictionary[token].strong_modal:
                _odata[7] += 1
            if lm_dictionary[token].weak_modal:
                _odata[8] += 1
            if lm_dictionary[token].constraining:
                _odata[9] += 1
            total_syllables += lm_dictionary[token].syllables

    # Compte le nombre de lettres majuscules dans le document
    _odata[10] = len(re.findall('[A-Z]', doc))

    # Compte le nombre de chiffres dans le document
    _odata[11] = len(re.findall('[0-9]', doc))

    # Supprime la ponctuation dans les nombres pour le comptage
    doc = re.sub('(?!=[0-9])(\.|,)(?=[0-9])', '', doc)

    # Remplace tous les caractères de ponctuation par des espaces dans le document
    doc = doc.translate(str.maketrans(
        string.punctuation, " " * len(string.punctuation)))

    # Compte le nombre de nombres dans le document
    _odata[12] = len(re.findall(r'\b[-+\(]?[$€£]?[-+(]?\d+\)?\b', doc))

    # Calcule la moyenne du nombre de syllabes par mot dans le document
    _odata[13] = total_syllables / _odata[2]

    # Calcule la longueur moyenne des mots dans le document
    _odata[14] = word_length / _odata[2]

    # Stocke la taille du dictionnaire de mots (vocabulaire unique) dans le document
    _odata[15] = len(vdictionary)

    # Conversion des comptages en pourcentage
    for i in range(3, 9 + 1):
        _odata[i] = (_odata[i] / _odata[2]) * 100

    return _odata


# Point d'entrée du programme
if __name__ == '__main__':
    start = dt.datetime.now()
    print(f'\n\n{start.strftime("%c")}\nPROGRAM NAME: {sys.argv[0]}\n')
    main()
    print(f'\n\nRuntime: {(dt.datetime.now()-start)}')
    print(f'\nNormal termination.\n{dt.datetime.now().strftime("%c")}\n')
