from WSCount import wordcount, sentencecount, counting

with open("TestDocument.txt", "r") as test_file:
    test_content = test_file.read()
    print("Contenu du fichier TestDocument.txt :")
    print(test_content)


def main():
    try:
        fog_index_calculated = ((wordcount()/sentencecount()) + counting())*0.4
        gunning_fog_index = ((wordcount()/sentencecount()) +
                             100*(counting()/wordcount()))*0.4

        # Afficher les valeurs calculées des indices de lisibilité
        print("Fog Index calculé :", fog_index_calculated)
        print("Gunning Fog Index calculé :", gunning_fog_index)

    except ZeroDivisionError:
        fog_index_calculated = gunning_fog_index = 0

    with open("FogIndex.txt", "w+") as new_file:
        new_file.write("The Fog Index of the given text document is " +
                       str(fog_index_calculated) + "\n")
        new_file.write(
            "The Gunning Fog Index of the given document is " + str(gunning_fog_index)+"\n")
        new_file.write("Total number of sentences = " +
                       str(sentencecount())+"\n")
        new_file.write("Total number of words = " + str(wordcount()) + "\n")
        new_file.write(
            "Total number of words with 3 or more syllables = " + str(counting()) + "\n")


if __name__ == '__main__':
    main()

# The fog index refers to a readability test that aims to determine the level
# of text difficulty, or how easy a text is to read.
# The index provides a reader with the number of years of education that
# he or she hypothetically needs to understand and digest a particular text on the first reading.

# To calculate a fog index score, we need to know the three following components:
# Average sentence length
# Percentage of long words present in the text
# Sum of the average sentence length and the percentage of long words

# To calculate the average sentence lenght, we need to divide the number of words by the number of sentences in a text sample.
# To find the percentage of long words, we divide the number of long words by the total number of words and multiply the result by 100.
# long word defined as a word with at least three syllabes

# There are a few exceptions to what is defined as a long word. Here is a list of the exceptions for long words:

# Words starting with a capital letter such as company names
# Combined “short-words” such as “share-holders” or “over-draft”
# Words with three syllables just because we added “ed” or “es” (e.g., created or practices)
# Short three-syllable words, such as “media”
