"""
Routine pour charger le dictionnaire principal
Version pour LM 2021 Dictionnaire Maître Temporaire

Bill McDonald
Date : 201510 Mise à jour : 202201 / 202308

"""

# Le fichier MOD_Load_MasterDictionary_v2023.py définit une fonction nommée load_masterdictionary. Cette fonction est conçue pour charger un dictionnaire principal à partir d'un fichier CSV spécifique, et le convertir en un dictionnaire Python utilisable dans la mémoire du programme.

import datetime as dt  # Importation du module datetime sous l'alias dt
import sys  # Importation du module sys


def load_masterdictionary(file_path, print_flag=False, f_log=None, get_other=False):
    start_local = dt.datetime.now()  # Enregistrement de l'heure de début
    # Configuration des dictionnaires
    _master_dictionary = {}  # Dictionnaire principal vide
    _sentiment_categories = ['negative', 'positive', 'uncertainty', 'litigious',
                             'strong_modal', 'weak_modal', 'constraining', 'complexity']  # Liste des catégories de sentiment
    _sentiment_dictionaries = dict()  # Dictionnaire de dictionnaires de sentiment
    for sentiment in _sentiment_categories:
        # Initialisation de chaque dictionnaire de sentiment
        _sentiment_dictionaries[sentiment] = dict()

    # Suppression des mots traditionnels : A, I, S, T, DON, WILL, AGAINST
    # Ajout : AMONG
    _stopwords = ['ME', 'MY', 'MYSELF', 'WE', 'OUR', 'OURS', 'OURSELVES', 'YOU', 'YOUR', 'YOURS',
                  'YOURSELF', 'YOURSELVES', 'HE', 'HIM', 'HIS', 'HIMSELF', 'SHE', 'HER', 'HERS', 'HERSELF',
                  'IT', 'ITS', 'ITSELF', 'THEY', 'THEM', 'THEIR', 'THEIRS', 'THEMSELVES', 'WHAT', 'WHICH',
                  'WHO', 'WHOM', 'THIS', 'THAT', 'THESE', 'THOSE', 'AM', 'IS', 'ARE', 'WAS', 'WERE', 'BE',
                  'BEEN', 'BEING', 'HAVE', 'HAS', 'HAD', 'HAVING', 'DO', 'DOES', 'DID', 'DOING', 'AN',
                  'THE', 'AND', 'BUT', 'IF', 'OR', 'BECAUSE', 'AS', 'UNTIL', 'WHILE', 'OF', 'AT', 'BY',
                  'FOR', 'WITH', 'ABOUT', 'BETWEEN', 'INTO', 'THROUGH', 'DURING', 'BEFORE',
                  'AFTER', 'ABOVE', 'BELOW', 'TO', 'FROM', 'UP', 'DOWN', 'IN', 'OUT', 'ON', 'OFF', 'OVER',
                  'UNDER', 'AGAIN', 'FURTHER', 'THEN', 'ONCE', 'HERE', 'THERE', 'WHEN', 'WHERE', 'WHY',
                  'HOW', 'ALL', 'ANY', 'BOTH', 'EACH', 'FEW', 'MORE', 'MOST', 'OTHER', 'SOME', 'SUCH',
                  'NO', 'NOR', 'NOT', 'ONLY', 'OWN', 'SAME', 'SO', 'THAN', 'TOO', 'VERY', 'CAN',
                  'JUST', 'SHOULD', 'NOW', 'AMONG']  # Liste des mots de liaison

    # Parcours des mots et chargement des dictionnaires
    with open(file_path) as f:
        _total_documents = 0  # Initialisation du nombre total de documents
        _md_header = f.readline()  # Lecture de la ligne d'en-tête
        print()  # Impression d'une ligne vide
        for line in f:  # Parcours des lignes du fichier
            # Séparation des colonnes par virgule
            cols = line.rstrip('\n').split(',')
            word = cols[0]  # Mot en première colonne
            # Création d'un objet MasterDictionary et stockage dans le dictionnaire principal
            _master_dictionary[word] = MasterDictionary(cols, _stopwords)
            for sentiment in _sentiment_categories:  # Parcours des catégories de sentiment
                # Vérification si le sentiment est présent pour ce mot #cette ligne vérifie si le mot actuel a une valeur non nulle pour un sentiment spécifique. Si c'est le cas, cela signifie que ce mot est associé à ce sentiment dans le dictionnaire principal.
                if getattr(_master_dictionary[word], sentiment):
                    # Stockage dans le dictionnaire de sentiment correspondant
                    _sentiment_dictionaries[sentiment][word] = 0
            # Mise à jour du nombre total de documents
            _total_documents += _master_dictionary[cols[0]].doc_count
            # Affichage périodique de l'avancement du chargement
            if len(_master_dictionary) % 5000 == 0 and print_flag:
                print(
                    f'\r ...Chargement du Dictionnaire Principal {len(_master_dictionary):,}', end='', flush=True)

    if print_flag:
        print('\r', end='')  # Effacement de la ligne
        # Affichage du chemin du fichier
        print(
            f'\nDictionnaire principal chargé depuis le fichier :\n  {file_path}\n')
        # Affichage du nombre de mots chargés
        print(
            f'  master_dictionary contient {len(_master_dictionary):,} mots.\n')

    if f_log:
        try:
            f_log.write('\n\n  FONCTION : load_masterdictionary' +
                        '(file_path, print_flag, f_log, get_other)\n')
            f_log.write(f'\n    file_path  = {file_path}')
            f_log.write(f'\n    print_flag = {print_flag}')
            f_log.write(f'\n    f_log      = {f_log.name}')
            f_log.write(f'\n    get_other  = {get_other}')
            f_log.write(
                f'\n\n    {len(_master_dictionary):,} mots chargés dans master_dictionary.\n')
            f_log.write(f'\n    Sentiment :')
            for sentiment in _sentiment_categories:
                f_log.write(
                    f'\n      {sentiment:13} : {len(_sentiment_dictionaries[sentiment]):8,}')
            f_log.write(
                f'\n\n  FIN DE LA FONCTION : load_masterdictionary : {(dt.datetime.now()-start_local)}')
        except Exception as e:
            print(
                'Le fichier journal dans load_masterdictionary n\'est pas disponible pour l\'écriture')
            print(f'Erreur = {e}')

    if get_other:
        # Retour des données supplémentaires
        return _master_dictionary, _md_header, _sentiment_categories, _sentiment_dictionaries, _stopwords, _total_documents
    else:
        return _master_dictionary  # Retour du dictionnaire principal


class MasterDictionary:
    def __init__(self, cols, _stopwords):
        for ptr, col in enumerate(cols):
            if col == '':
                cols[ptr] = '0'
        try:
            self.word = cols[0].upper()  # Mot en majuscules
            self.sequence_number = int(cols[1])  # Numéro de séquence
            self.word_count = int(cols[2])  # Nombre de mots
            self.word_proportion = float(cols[3])  # Proportion du mot
            self.average_proportion = float(cols[4])  # Proportion moyenne
            self.std_dev_prop = float(cols[5])  # Écart type de la proportion
            self.doc_count = int(cols[6])  # Nombre de documents
            self.negative = int(cols[7])  # Négatif
            self.positive = int(cols[8])  # Positif
            self.uncertainty = int(cols[9])  # Incertitude
            self.litigious = int(cols[10])  # Litigieux
            self.strong_modal = int(cols[11])  # Modal fort
            self.weak_modal = int(cols[12])  # Modal faible
            self.constraining = int(cols[13])  # Contrainte
            self.complexity = int(cols[14])  # Complexité
            self.syllables = int(cols[15])  # Nombre de syllabes
            self.source = cols[16]  # Source du mot
            if self.word in _stopwords:
                self.stopword = True  # Indicateur de mot de liaison
            else:
                self.stopword = False
        except:
            print('ERREUR dans la classe MasterDictionary')
            print(f'mot = {cols[0]} : numseq = {cols[1]}')
            quit()  # Arrêt du programme en cas d'erreur
        return  # Fin de l'initialisation


if __name__ == '__main__':
    start = dt.datetime.now()  # Enregistrement de l'heure de début
    # Affichage de l'heure de début et du nom du programme
    print(f'\n\n{start.strftime("%c")}\nNOM DU PROGRAMME : {sys.argv[0]}\n')
    # Ouverture du fichier journal en écriture
    f_log = open('D:\Temp\Load_MD_Logfile.txt', 'w')
    # Chemin vers le fichier CSV
    md = ('/Users/melis/Desktop/Loughran-McDonald_MasterDictionary_1993-2023.csv')
    master_dictionary, md_header, sentiment_categories, sentiment_dictionaries, stopwords, total_documents = \
        load_masterdictionary(
            md, True, f_log, True)  # Chargement du dictionnaire principal
    # Affichage de la durée d'exécution
    print(f'\n\nDurée d\'exécution : {(dt.datetime.now()-start)}')
    # Affichage de l'heure de fin
    print(f'\nTerminaison normale.\n{dt.datetime.now().strftime("%c")}\n')
