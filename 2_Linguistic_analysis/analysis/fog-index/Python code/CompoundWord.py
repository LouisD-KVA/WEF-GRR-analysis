import enchant  # Importe la bibliothèque enchant pour la vérification des mots
import sys  # Importe le module sys pour interagir avec le système d'exploitation

# Nécessite la bibliothèque PyEnchant

# Pour pouvoir supporter Python 2 & 3
if sys.version_info[0] > 2:
    unicode = str  # Définit unicode comme str pour Python 3


def __concat(object1, object2):
    # Fonction interne pour concaténer deux objets
    if isinstance(object1, str) or isinstance(object1, unicode):
        object1 = [object1]
    if isinstance(object2, str) or isinstance(object2, unicode):
        object2 = [object2]
    return object1 + object2


def __capitalize_first_char(word):
    # Fonction interne pour mettre la première lettre d'un mot en majuscule
    return word[0].upper() + word[1:]


def __split(word, language='en_US'):
    # Fonction interne pour diviser un mot composé
    # Utilise un dictionnaire enchant pour la vérification des mots
    dictionary = enchant.Dict(language)
    max_index = len(word)

    if max_index < 3:  # Si la longueur du mot est inférieure à 3, retourne le mot intact
        return word

    for index, char in enumerate(word, 2):
        # Itère à travers les caractères du mot à partir du deuxième caractère

        left_word = word[0:index]  # Partie gauche du mot
        right_word = word[index:]  # Partie droite du mot

        if index == max_index - 1:
            break  # Arrête si l'index atteint l'avant-dernier caractère du mot

        if dictionary.check(left_word) and dictionary.check(right_word):
            # Vérifie si les deux parties du mot sont des mots valides
            return [compound for compound in __concat(left_word, right_word)]

    return word  # Si aucune division n'est possible, retourne le mot intact


def split(compound_word, language='en_US'):
    # Fonction principale pour diviser un mot composé
    # Divise le mot composé en mots individuels
    words = compound_word.split('-')

    word = ""
    for x in words:
        word += x  # Concatène les mots individuels pour former un seul mot

    # Applique la division interne sur le mot formé
    result = __split(word, language)

    if result == compound_word:
        # Si le résultat est le même que le mot composé d'origine, retourne le mot intact
        return [result]

    return result  # Retourne le résultat de la division
