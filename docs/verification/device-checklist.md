# Test sur iPhone : « Fait » avec l'app fermée

Ce test ne peut pas se faire dans le simulateur. Durée : environ 10 minutes.

1. Branche ton iPhone au Mac et déverrouille-le.
2. Dans le Terminal : `cd ~/projets/groove && xcodegen generate && open GrooveCore.xcodeproj`
3. Dans Xcode, choisis ton iPhone en haut, puis ▶ (Run). La première fois, iOS demande de faire confiance au développeur : Réglages > Général > VPN et gestion de l'appareil.
4. Fais le premier lancement (2 exercices suffisent) et accepte les notifications.
5. Dans Réglages de l'app, mets l'intervalle à 20 min et le début de plage à l'heure actuelle.
6. Ferme l'app complètement : balaye-la vers le haut depuis le sélecteur d'apps.
7. Attends le rappel (20 min au plus). Appui long sur la notif, puis « Fait ».
8. Rouvre l'app : les bâtons des exercices du bloc ont avancé d'un cran, et le prochain bloc est le suivant.
9. Refais 6 et 7 avec « Passer » : rien n'est noté, et les séries du bloc sont redistribuées dans les blocs suivants.

Si l'étape 8 échoue, note l'heure du rappel et envoie-moi une capture de l'écran Aujourd'hui.

10. Tape sur le corps d'une notification pendant que l'app est sur un autre onglet, puis refais le test avec l'app complètement fermée : dans les deux cas, le détail du bloc doit s'ouvrir.
11. Change une valeur dans Réglages pendant que l'app est ouverte, puis vérifie que l'heure du prochain rappel a changé en conséquence.
12. Fais le premier lancement avec 10 exercices : la ligne de débordement doit apparaître si les séries ne tiennent pas dans la journée, ou dire que le programme tient sinon.
