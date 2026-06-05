import re
import sys
from SyllableCounter import syllables
from CompoundWord import split  # La fonction split est utilisée ici pour diviser le contenu du fichier en mots individuels. Cela est nécessaire pour traiter chaque mot séparément dans les itérations ultérieures de la boucle for word in words:. Cette division permet également de prendre en charge les mots composés, car ils sont traités comme un seul mot avec un trait d'union. Ainsi, cette utilisation de la fonction split contribue à l'analyse précise des mots et à la comptabilisation des syllabes, des mots et des phrases dans le texte.

try:
    # Ouvre le fichier en mode lecture
    FileObject = open("TestDocument.txt", "r")
except FileNotFoundError:
    # Crée un nouveau fichier si le fichier n'est pas trouvé
    with open("FileNotFound.txt", "w+") as new_file:
        new_file.write("File does not exist, please try again by placing a valid file named 'TestDocument.txt' in "
                       "current directory")
    sys.exit(0)  # Quitte le programme si le fichier n'est pas trouvé

file_contents = FileObject.read()  # Lit le contenu du fichier


def counting():
    syllablecount = 0  # Initialise le compteur de syllabes
    # Trouve le début de chaque phrase
    beg_each_Sentence = re.findall(r"\.\s*(\w+)", file_contents)
    # Trouve les mots en majuscules (qui commencent par une majuscule)
    capital_words = re.findall(r"\b[A-Z][a-z]+\b", file_contents)
    words = file_contents.split()  # Divise le contenu du fichier en mots
    # print(words)
    # print(capital_words)
    vowels = "aeiouy"  # Liste de voyelles
    for word in words:
        # Afficher le mot en cours de traitement
        #print("Processing word:", word)
        if len(word) >= 3 and word[1] not in vowels:
            if word.lower() not in capital_words:  # Cette condition vérifie si le mot, en minuscules, n'est pas présent dans la liste capital_words. Cela pourrait être utilisé pour exclure les mots qui sont en majuscules dans le texte d'origine.

                # Cette condition vérifie si le nombre de syllabes dans le mot est supérieur ou égal à 3 et si le mot n'est pas vide après suppression des espaces blancs. Si ces conditions sont vérifiées, cela signifie que le mot a au moins 3 syllabes et qu'il n'est pas vide.
                if syllables(word) >= 3 and word.strip() != '':
                    syllablecount += 1

        # Cette condition vérifie si le mot est présent à la fois dans la liste capital_words et dans la liste beg_each_Sentence. Cela pourrait être utilisé pour vérifier si le mot commence une nouvelle phrase et s'il est en majuscules.
        if word in capital_words and word in beg_each_Sentence:
            if syllables(word) >= 3:  # Vérifie si le nombre de syllabes >= 3
                syllablecount += 1
    return syllablecount


def wordcount():
    # Regex pour trouver tous les mots, les mots avec des tirets sont comptés comme des mots composés
    return len(re.findall("[a-zA-Z-]+", file_contents))


def sentencecount():
    # Regex pour compter les phrases, peut se terminer par un point, un point d'interrogation ou un point d'exclamation
    return (len(re.split("[.!?]+", file_contents)) - 1)


FileObject.close()  # Ferme le fichier
