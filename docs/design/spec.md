# GrooveCore : spec de conception

Date : 26 septembre 2026. Nom de l'app : **GrooveCore** (libre sur l'App Store FR et US au 26 sept. 2026 ; « GtG » écarté, déjà pris par GtG Counter, Grease the Groove: GTG Coach, Notch: GTG Watch Timer).
Charte graphique et maquettes : `docs/design/charte.html` (version groseille, validée).

## 1. But

Une app iOS pour suivre un programme **grease the groove** (GtG) : beaucoup de petites séries sous-maximales réparties dans la journée.

Ce que Mei a dit :
- les apps du store sont payantes, avec pub ou compte obligatoire, ou mal faites ;
- programme piloté par un test de max et un %, mais tout reste modifiable à la main ;
- rappels répartis sur une plage horaire, avec un bouton « Fait » dans la notif qui note sans ouvrir l'app ;
- bibliothèque poids du corps + exercices perso ;
- **au moins 10 exercices actifs en même temps**, donc un rappel = un mini-bloc de plusieurs exercices ;
- usage perso d'abord (iPhone de Mei), App Store plus tard peut-être ;
- inspirée de You Can Do Hiit, mais avec sa propre couleur (groseille) ;
- **français et anglais dès la v1** ;
- **on peut ajouter ses propres exercices**.

Critère de réussite : Mei suit son programme une semaine entière en notant ses blocs depuis les notifs, sans ouvrir l'app sauf pour les re-tests et les réglages.

Hors périmètre v1 : widget, Apple Watch, synchro iCloud, compte, export, fiche App Store, Android.

## 2. Stack

- SwiftUI, SwiftData, UserNotifications, BackgroundTasks. Aucune dépendance tierce.
- iOS 18 minimum, iPhone seulement, portrait.
- Projet Xcode généré par **XcodeGen** (`project.yml` versionné, `.xcodeproj` ignoré par git).
- Bundle ID `com.maelrochard.groovecore`, nom affiché `GrooveCore`, équipe `85228RBZF6`.
- Deux cibles :
  - **`GrooveKit`** : package Swift local, logique pure (Foundation seulement), testé avec `swift test`.
  - **`GrooveCore`** : l'app. Écrans, persistance, notifications. Toute règle métier passe par `GrooveKit`.
- **Langues** : français et anglais via des fichiers `Localizable.strings` générés depuis `scripts/strings.tsv` (région de développement `en`). L'app suit la langue d'iOS, avec l'anglais comme repli pour toute autre langue. Aucune chaîne visible en dur : écrans, notifs (titre, corps, actions), noms des exercices prédéfinis (clé `builtinKey`), unités (« / jambe » / « / leg », « s »). Formats de date et d'heure via `FormatStyle` (14:30 en FR, 2:30 PM en EN selon les réglages de l'iPhone).

## 3. Modèle de données (SwiftData, local)

| Entité | Champs |
|---|---|
| `Exercise` | `id`, `name` (nil pour un prédéfini, dont le nom vient du String Catalog), `unit` (`reps` / `seconds`), `perSide` (bool), `builtinKey` (nil si perso), `isArchived` |
| `Program` | `id`, `exercise`, `isActive`, `order`, `maxValue`, `workPercent` (défaut 50), `manualReps` (nil = calculé), `dailySets` (défaut 8), `retestIntervalDays` (défaut 10), `lastTestDate` |
| `MaxTest` | `id`, `exercise`, `date`, `value` |
| `SetLog` | `id`, `exercise`, `date`, `reps`, `blockId` (nil si noté à la main) |
| `SkippedBlock` | `blockId`, `date` |
| `DayTarget` | `day` (date locale), `targets` ([exerciseId: séries]) : figé au premier calcul du jour, mis à jour si un programme est ajouté ou modifié dans la journée |

Réglages (`UserDefaults`) : début et fin de plage (défaut 8:00 et 20:00), intervalle (défaut 45 min, minimum 20), taille maximale d'un bloc (défaut 5), jours de repos (défaut aucun), % par défaut (50), son de notif (oui).

**Exercices perso** : depuis la bibliothèque, « Nouvel exercice » demande un nom (1 à 40 caractères, sans doublon avec un exercice non archivé, casse ignorée), l'unité (reps ou secondes) et « par côté ». On peut ensuite modifier le nom et « par côté » ; l'unité est figée dès qu'une série ou un test existe. Supprimer un exercice perso sans historique le supprime ; avec historique, il est archivé (retiré de la bibliothèque et du programme, historique conservé). Le nom perso s'affiche tel quel dans les deux langues. Les exercices prédéfinis ne se suppriment pas.

Bibliothèque de départ : tractions, chin-ups, pompes, pompes diamant, dips, squats, pistol squat (par jambe), fentes (par jambe), gainage (s), hollow hold (s).

## 4. Règles métier (`GrooveKit`)

**Reps de travail** : `manualReps` s'il existe, sinon `max(1, arrondi(maxValue × workPercent / 100))`, arrondi au plus proche (0,5 vers le haut). Même règle en secondes.

**Re-test** : dû quand `aujourd'hui ≥ lastTestDate + retestIntervalDays`. Un nouveau max crée un `MaxTest`, met à jour `maxValue` et `lastTestDate`. Si `manualReps` est défini, l'app demande « Garder tes reps / Recalculer à X ».

**Statut d'un jour** (d'après `DayTarget` et les `SetLog`) :
- `repos` : jour de repos choisi ;
- `complet` : chaque exercice a atteint ses séries cibles ;
- `partiel` : au moins une série, sans être complet ;
- `manqué` : zéro série un jour qui n'est pas un jour de repos.

**Streak** : nombre de jours `complet` consécutifs en remontant depuis hier ; les jours de repos sont sautés (ils ne comptent pas et ne cassent rien). Aujourd'hui s'ajoute s'il est déjà complet. Le record est la plus longue suite de ce type.

**Dates** : toujours `Calendar.current` et le fuseau local. Jamais de `toISOString` ni de date UTC pour définir un jour.

## 5. Planificateur de blocs (`GrooveKit`)

Entrées : créneaux restants du jour, séries restantes par exercice (cible − faites), ordre des programmes, taille maximale d'un bloc `B`, exercices du dernier bloc noté ou passé.

Créneaux : `début + k × intervalle`, jusqu'à la fin de plage incluse ; pour aujourd'hui, seulement ceux qui restent à venir.

Pour chaque créneau, dans l'ordre, avec `S` = créneaux restants (celui-ci compris) :
1. Chaque série restante d'un exercice reçoit un créneau idéal : ses séries sont espacées régulièrement sur les créneaux restants, avec un décalage propre à chaque exercice (nombre d'or) pour que les exercices ne tombent pas tous sur les mêmes créneaux.
2. On parcourt les créneaux dans l'ordre. Les séries dont le créneau idéal est arrivé rejoignent une file d'attente.
3. Chaque créneau prend jusqu'à `B` exercices **différents** dans la file : créneau idéal le plus ancien d'abord, puis ceux qui n'étaient pas dans le bloc précédent, puis l'ordre du programme. Le reste attend le créneau suivant.
4. Un exercice du dernier bloc noté ou passé commence au deuxième créneau (s'il a moins de séries que de créneaux).
5. Ce qui reste dans la file après le dernier créneau est le débordement.

**Débordement** : nombre de séries restées dans la file après le dernier créneau (journée trop courte, blocs trop petits, ou un exercice qui a plus de séries que de créneaux). Les Réglages l'affichent et proposent de baisser un objectif, d'élargir la plage ou de raccourcir l'intervalle.

**Passer** : crée un `SkippedBlock`. Les séries du bloc restent à faire et sont redistribuées au recalcul suivant.

**Série notée à la main** : ajoute un `SetLog` sans `blockId` ; le reste du jour est recalculé.

Jours suivants : même algorithme sur toute la plage, cibles complètes, sans bloc précédent. Jours de repos : aucun créneau.

## 6. Notifications

- Autorisation demandée à la fin du premier lancement.
- Une notif par bloc : `UNCalendarNotificationTrigger` non répétitif, construit à partir de composantes de date locales (le changement d'heure est géré par le calendrier).
- Identifiant = `blockId` = `yyyy-MM-dd-HHmm` local.
- Titre « Bloc de 14:30 », corps « 5 tractions · 12 pompes · 3 pistol squats » (« / jambe » et « s » selon l'exercice).
- `userInfo` contient le bloc complet : `blockId` et la liste `{exerciseId, reps}`. Noter depuis la notif ne dépend donc d'aucun recalcul.
- Catégorie `BLOCK`, actions `done` (« Fait ») et `skip` (« Passer »), toutes deux **sans** `.foreground`. Un tap simple ouvre le détail du bloc.
- `UNUserNotificationCenterDelegate.didReceive` : `done` crée les `SetLog` (en ignorant un `blockId` déjà présent, pour qu'un double tap ne compte qu'une fois), `skip` crée le `SkippedBlock`. Puis reprogrammation et appel du completion handler.
- **Fenêtre de programmation** : de maintenant à 14 jours au plus, 60 notifs au plus (limite iOS : 64). On supprime tout ce qui est en attente, puis on reprogramme.
- Reprogrammation déclenchée à : ouverture de l'app, bloc noté ou passé (app ou notif), série à la main, changement de programme ou de réglage, tâche `BGAppRefreshTask` quotidienne (au mieux, iOS ne la garantit pas).
- Notifs refusées : bandeau sur Aujourd'hui avec un lien vers les Réglages iOS ; l'app reste utilisable à la main.

## 7. Écrans

Référence visuelle : `docs/design/charte.html`.

Tab bar à 4 onglets : **Aujourd'hui**, **Programme**, **Historique**, **Réglages**.

- **Premier lancement** : (1) choisir ses exercices ou en créer un ; (2) pour chacun, entrer le max connu ou le tester ; (3) plage horaire et jours de repos, puis autorisation des notifs.
- **Aujourd'hui** : date et streak ; carte « Prochain bloc » (heure, exercices, reps, Fait / Passer) ; carte ambre de re-test si dû ; liste des exercices avec leurs bâtons (fait / restant) et « x / y » ; un tap sur un exercice ouvre un sheet avec +1 série. Après chaque bloc noté, bandeau « Annuler » pendant 5 s.
- **Détail d'un bloc** (tap sur la notif ou sur le prochain bloc) : reps modifiables par exercice avant de valider.
- **Programme** : liste des exercices actifs (reps, objectif), pause, réordonner, bouton « Ajouter » vers la bibliothèque.
- **Bibliothèque** : prédéfinis et perso, « Nouvel exercice », modifier et supprimer / archiver un exercice perso (glisser ou fiche).
- **Fiche exercice** : max, % et reps (modifiables), séries par jour, intervalle de re-test, courbe des tests de max, bouton de re-test.
- **Test de max** : plein écran, gros compteur +1, ou chrono pour les exercices en secondes ; à la validation, affichage des nouvelles reps (confirmation si reps manuelles).
- **Historique** : calendrier du mois (complet / partiel / repos / manqué / aujourd'hui), puis volume de la semaine par exercice.
- **Réglages** : plage, intervalle, taille de bloc, jours de repos, % par défaut, son, état des notifs, alerte de débordement.

Charte :
- couleurs : graphite `#0E0F10`, ardoise `#1C1D1E` / `#27282A`, craie `#EDEAE3`, groseille `#FF4D6D` (réservée à l'action du moment), menthe `#5FD39A` (objectif atteint), ambre `#F5B83D` (re-test) ;
- mode clair : fond `#F3F2EF`, encre `#1C1B19`, groseille `#D42A50`, menthe `#1F9D63` ;
- typo SF Pro seulement, compteurs en Display Heavy avec chiffres à chasse fixe (`monospacedDigit`) ;
- cartes sans ombre ;
- l'unité visuelle est le bâton de comptage, groupé par 5 ;
- haptique `success` au bloc noté, `rigid` sur +1 ;
- animation du bâton en 180 ms, coupée si « Réduire les animations » est actif.

## 8. Tests

Automatiques, écrits avant le code (TDD), sur `GrooveKit` avec `swift test` :
- reps : arrondi, minimum 1, reps manuelles prioritaires, re-test avec et sans reps manuelles ;
- re-test dû : bornes exactes ;
- statut d'un jour et streak : repos sauté, partiel qui casse la série, aujourd'hui incomplet non compté, record ;
- planificateur : toutes les séries placées quand ça tient, jamais plus de `B` exercices par bloc, pas le même exercice deux fois d'affilée quand c'est évitable, étalement, redistribution après Passer, débordement détecté ;
- créneaux et fenêtre : 60 notifs au plus, 14 jours au plus, jours de repos vides, **passage à l'heure d'hiver du 25 octobre 2026** (Europe/Paris), créneaux autour de minuit ;
- payload de notif : aller-retour encodage / décodage identique ;
- validation d'un nom d'exercice perso : vide, trop long, doublon (casse ignorée), doublon avec un archivé autorisé.

Côté app (XCTest, SwiftData en mémoire) : « Fait » idempotent sur un même `blockId`, « Passer » qui redistribue, suppression d'un exercice perso (supprimé sans historique, archivé avec), corps de notif en FR et en EN. Un script vérifie que chaque clé du String Catalog a une traduction `en` et `fr`.

À la main :
- capture de chaque écran dans le simulateur, comparée à la charte, en FR puis en EN (texte coupé, débordement) ;
- sur l'iPhone de Mei, **app tuée** : « Fait » depuis la notif doit noter le bloc et reprogrammer la suite.
