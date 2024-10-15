def syllables(word):
    if len(word) <= 1:
        return 0  # Retourne 0 si le mot a une longueur inférieure ou égale à 1

    word = word.lower()  # Convertit le mot en minuscules
    word = word + " "  # Ajoute un espace à la fin du mot
    length = len(word)  # Stocke la longueur du mot dans une variable
    ending = ["ing ", "ed ", "es ", "ous ", "tion ",
              "nce ", "ness "]  # Liste des terminaisons à exclure lors du comptage des syllabes

    for end in ending:
        if word.strip().endswith(end):  # Vérifie si le mot se termine par une des terminaisons (car le cas échéant, il faut prendre en compte 'ing' ou 'ion' utilisé tout seul)
            word = word.replace(end, "")  # Supprime la terminaison

    syllable_count = 0  # Initialise le compteur de syllabes

    if word.strip().endswith("ing"):
        syllable_count += 1  # Incrémente le compteur de syllabes si le mot se termine par "ing"

    if len(word) > 0 and word[-1] == " " and len(word) > 1:
        word = word[:-1]  # Supprime l'espace à la fin du mot si présent

    if word[-1] == "e":
        try:
            if word[-3:] == "nce" and word[-3:] == "rce":
                # Réinitialise le compteur de syllabes si le mot se termine par "nce" ou "rce"
                syllable_count = 0
            elif word[-3] not in "aeiouy" and word[-2] not in "aeiouy" and word[-3:] != "nce" and word[-3:] != "rce":
                if word[-3] != "'":
                    # Incrémente le compteur de syllabes si la suppression de "e" contribue à une syllabe
                    syllable_count += 1
            word = word[:-1]  # Supprime le "e" à la fin du mot
        except IndexError:
            syllable_count += 0  # Gère les erreurs d'index

    one_syllable_beg = ["ya", "ae", "oe", "ea", "yo",
                        "yu", "ye"]  # Liste de combinaisons de lettres formant une syllabe au début d'un mot

    two_syllables = ["ao", "uo", "ia", "eo", "ea", "uu",
                     "eous", "uou", "ii", "io", "ua", "ya", "yo", "yu", "ye"]  # Liste de combinaisons de lettres formant deux syllabes

    last_letter = str()  # Initialise la dernière lettre

    for index, alphabet in enumerate(word):  # Parcours chaque lettre du mot
        if alphabet in "aeiouy":  # Vérifie si la lettre est une voyelle
            # Combine la lettre actuelle avec la dernière
            current_combo = last_letter + alphabet
            if len(current_combo) == 1:  # Si c'est la première lettre de la combinaison
                if len(word) >= 2 and word[1] not in "aeiouy":
                    # Incrémente le compteur de syllabes si la deuxième lettre n'est pas une voyelle
                    syllable_count += 1
                    last_letter = word[1]
                else:
                    # Incrémente le compteur de syllabes si la lettre actuelle est une voyelle
                    syllable_count += 1
                    last_letter = alphabet

            else:
                if current_combo in two_syllables:  # Vérifie si la combinaison de lettres forme deux syllabes
                    try:
                        if current_combo == word[:2] and current_combo in one_syllable_beg:
                            # N'incrémente pas le compteur de syllabes si la combinaison est au début du mot
                            syllable_count += 0
                        elif index >= 2 and index < len(word) - 1 and word[index - 2] + current_combo + word[index + 1] == "tion" or word[index - 2] + current_combo + \
                                word[index + 1] == "sion":
                            # N'incrémente pas le compteur de syllabes dans certains cas spécifiques
                            syllable_count += 0
                        else:
                            syllable_count += 1  # Incrémente le compteur de syllabes
                        last_letter = alphabet  # Stocke la dernière lettre
                    except IndexError:
                        syllable_count += 0  # Gère les erreurs d'index

                else:
                    if last_letter not in "aeiouy":
                        # Incrémente le compteur de syllabes si la dernière lettre n'est pas une voyelle
                        syllable_count += 1
                        last_letter = alphabet

                    else:
                        last_letter = alphabet

    if word[-3:] == "ier":
        syllable_count += 1  # Incrémente le compteur de syllabes si le mot se termine par "ier"

    return syllable_count  # Retourne le nombre de syllabes dans le mot


print(syllables('fabulous'))
print(syllables('workshop'))
