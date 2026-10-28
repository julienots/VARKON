#!/usr/bin/env python3
"""UI strings (French source + English) -> localization/strings.csv.

    python3 tools/strings.py          # writes the CSV and reports missing keys

Every key used by the code (tr("KEY"), Router.error("KEY"), dynamic prefixes) must exist here.
"""
import csv
import json
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(__file__), "..")

S = {
    # ---- Menu / navigation
    "MENU_COMBAT": ("Combat", "Battle"), "MENU_COLLECTION": ("Collection", "Collection"), "MENU_BASE": ("Ma base", "My base"),
    "MENU_KING": ("King Gobelin", "Goblin King"), "MENU_SHOP": ("Boutique", "Shop"), "MENU_CHESTS": ("Coffres", "Chests"),
    "MENU_MISSIONS": ("Missions", "Missions"), "MENU_PASS": ("Pass", "Pass"), "MENU_EVENTS": ("Événements", "Events"),
    "MENU_ACHIEVEMENTS": ("Succès", "Achievements"), "MENU_INVENTORY": ("Inventaire", "Inventory"), "MENU_SETTINGS": ("Paramètres", "Settings"),
    "MENU_LAB": ("Laboratoire", "Laboratory"),
    # ---- Buttons
    "BTN_OK": ("OK", "OK"), "BTN_CANCEL": ("Annuler", "Cancel"), "BTN_CONFIRM": ("Confirmer", "Confirm"), "BTN_BACK": ("Retour", "Back"),
    "BTN_CLOSE": ("Fermer", "Close"), "BTN_FIGHT": ("Combattre", "Fight"), "BTN_DECK": ("Mon deck", "My deck"), "BTN_GO": ("Voir", "Go"),
    "BTN_PAUSE": ("Pause", "Pause"), "BTN_RESUME": ("Reprendre", "Resume"), "BTN_FORFEIT": ("Abandonner", "Forfeit"), "BTN_EMOTE": ("Emote", "Emote"),
    "BTN_MENU": ("Menu", "Menu"), "BTN_RETRY": ("Rejouer", "Retry"), "BTN_NEXT_MISSION": ("Mission suivante", "Next mission"),
    "BTN_UPGRADE": ("Améliorer", "Upgrade"), "BTN_ADD_DECK": ("Ajouter au deck", "Add to deck"), "BTN_REMOVE_DECK": ("Retirer du deck", "Remove from deck"),
    "BTN_EQUIP": ("Équiper", "Equip"), "BTN_UNEQUIP": ("Retirer", "Unequip"), "BTN_ACTIVATE": ("Activer", "Activate"), "BTN_DEACTIVATE": ("Désactiver", "Deactivate"),
    "BTN_UNLOCK": ("Débloquer", "Unlock"), "BTN_SAVE": ("Enregistrer", "Save"), "BTN_LOAD": ("Charger", "Load"), "BTN_DELETE": ("Supprimer", "Delete"),
    "BTN_BUILD": ("Construire", "Build"), "BTN_ZONES": ("Zones", "Zones"), "BTN_COLLECT_ALL": ("Tout collecter", "Collect all"), "BTN_COLLECT": ("Collecter", "Collect"),
    "BTN_MOVE": ("Déplacer", "Move"), "BTN_ROTATE": ("Pivoter", "Rotate"), "BTN_PLACE": ("Placer", "Place"), "BTN_SPEEDUP": ("Accélérer (%d cristaux)", "Speed up (%d crystals)"),
    "BTN_REPAIR": ("Réparer", "Repair"), "BTN_CRAFT": ("Fabriquer", "Craft"), "BTN_RESEARCH": ("Rechercher", "Research"), "BTN_RECYCLE": ("Recycler", "Recycle"),
    "BTN_OPEN": ("Ouvrir", "Open"), "BTN_ODDS": ("Probabilités", "Odds"), "BTN_BUY": ("Acheter", "Buy"), "BTN_PREVIEW": ("Aperçu", "Preview"),
    "BTN_CLAIM": ("Réclamer", "Claim"), "BTN_CLAIM_ALL": ("Tout réclamer", "Claim all"), "BTN_BUY_PREMIUM": ("Voie premium — %d cristaux", "Premium track — %d crystals"),
    "BTN_DUMMIES": ("Mannequins d'entraînement", "Training dummies"), "BTN_VS_BOT": ("Contre un bot (%s)", "Against a bot (%s)"), "BTN_REPLAY": ("Rejouer", "Play again"),
    "BTN_RESET_SETTINGS": ("Réinitialiser les paramètres", "Reset settings"), "BTN_SAVE_NOW": ("Sauvegarder maintenant", "Save now"),
    "BTN_RESET_PROFILE": ("Effacer la progression", "Erase progress"), "BTN_CONTINUE": ("Continuer", "Continue"),
    # ---- Labels
    "LBL_LEVEL": ("Niveau %d", "Level %d"), "LBL_LEVEL_SHORT": ("N.%d", "L.%d"), "LBL_NEXT": ("Suivante", "Next"), "LBL_KING": ("King Gobelin", "Goblin King"),
    "LBL_KING_RESPAWN": ("Retour du King dans %d s", "King returns in %d s"), "LBL_DOUBLE_RAGE": ("RAGE x2", "RAGE x2"), "LBL_WAVE": ("Vague %d / %d", "Wave %d / %d"),
    "LBL_WAVE_ENDLESS": ("Vague %d", "Wave %d"), "LBL_ARMOR": ("Armure", "Armor"), "LBL_PHASE": ("Phase", "Phase"), "LBL_PAUSE": ("Pause", "Paused"),
    "LBL_VICTORY": ("Victoire !", "Victory!"), "LBL_DEFEAT": ("Défaite", "Defeat"), "LBL_DRAW": ("Égalité", "Draw"), "LBL_STATS": ("Statistiques", "Statistics"),
    "LBL_REWARDS": ("Récompenses", "Rewards"), "LBL_NO_REWARDS": ("Aucune récompense supplémentaire.", "No extra rewards."),
    "LBL_TRAINING_NO_REWARDS": ("L'entraînement ne donne pas de récompense.", "Training gives no rewards."), "LBL_NEW": ("Nouvelle !", "New!"),
    "LBL_CAMPAIGN": ("Campagne", "Campaign"), "LBL_CHAPTER": ("Chapitre %d", "Chapter %d"), "LBL_STARS_CHAPTER": ("Étoiles : %d / %d", "Stars: %d / %d"),
    "LBL_ENEMY_LEVEL": ("Niveau ennemi %d", "Enemy level %d"), "LBL_ENEMY_DECK": ("Deck ennemi", "Enemy deck"), "LBL_FIRST_CLEAR": ("Première victoire", "First clear"),
    "LBL_DEFENSES": ("Vos défenses : %d segments de muraille, %d pièges, tours +%d %%", "Your defenses: %d wall segments, %d traps, towers +%d %%"),
    "LBL_SURVIVAL_BEST": ("Record : %d vagues", "Best: %d waves"), "LBL_WEEKLY_EVENT": ("Événement de la semaine", "Weekly event"),
    "LBL_COLLECTION_COUNT": ("%d / %d cartes", "%d / %d cards"), "LBL_IN_DECK": ("Dans le deck", "In deck"), "LBL_SYNERGY": ("Synergie", "Synergy"),
    "LBL_MAX_LEVEL": ("Niveau maximum atteint", "Maximum level reached"), "LBL_COPIES": ("Copies : %d / %d", "Copies: %d / %d"),
    "LBL_FRAGMENTS_REPLACE": ("%d copie(s) manquante(s) remplacée(s) par %d fragments.", "%d missing cop(ies) replaced by %d fragments."),
    "LBL_NOT_OWNED": ("Carte non possédée", "Card not owned"), "LBL_OBTAIN_CARD": ("Obtenable dans les coffres à partir du niveau %d, la boutique et la campagne.", "Obtainable from chests from level %d, the shop and the campaign."),
    "LBL_DECK_SIZE": ("Deck : %d / %d", "Deck: %d / %d"), "LBL_AVG_COST": ("Coût moyen : %.1f", "Average cost: %.1f"), "LBL_SWAP_HINT": ("Touchez la carte à remplacer par %s", "Tap the card to replace with %s"),
    "LBL_ACTIVE_SYNERGIES": ("Synergies actives :", "Active synergies:"), "LBL_NONE": ("Aucun", "None"), "LBL_DECK_PICK_HINT": ("Touchez une carte de votre collection pour l'échanger.", "Tap a collection card to swap it in."),
    "LBL_DECK_TAP_HINT": ("Touchez une carte du deck pour la remplacer.", "Tap a deck card to replace it."), "LBL_POWER": ("Puissance %d", "Power %d"),
    "LBL_DRAG_ROTATE": ("Glissez pour faire pivoter le King.", "Drag to rotate the King."), "LBL_EMPTY": ("Vide", "Empty"), "LBL_NO_ITEM_SLOT": ("Aucun objet pour cet emplacement. Coffres, boutique, fabrication et pass en fournissent.", "No item for this slot yet. Chests, shop, crafting and the pass provide them."),
    "LBL_COSMETIC": ("Cosmétique", "Cosmetic"), "LBL_COSMETIC_ONLY": ("Purement esthétique", "Cosmetic only"), "LBL_ORIGIN": ("Origine", "Source"),
    "LBL_RELIC_LEVEL": ("Relique niveau %d", "Relic level %d"), "LBL_LOCKED_OPTION": ("%s verrouillé : %s", "%s locked: %s"), "LBL_MUTATION_SLOTS": ("Mutations actives : %d / %d", "Active mutations: %d / %d"),
    "LBL_SAVED": ("Enregistrée", "Saved"), "LBL_NONE_OWNED": ("Aucun possédé", "None owned"), "LBL_ACTIVE_EFFECTS": ("Effets actifs", "Active effects"),
    "LBL_YES": ("Oui", "Yes"), "LBL_NO": ("Non", "No"), "LBL_FORTRESS_LEVEL": ("Forteresse niv. %d", "Fortress lv. %d"), "LBL_BUILDERS": ("Bâtisseurs : %d / %d", "Builders: %d / %d"),
    "LBL_LOCKED": ("Verrouillé", "Locked"), "LBL_UNLOCKED": ("Débloquée", "Unlocked"), "LBL_PRODUCTION": ("Production", "Production"), "LBL_STORED": ("En stock", "Stored"),
    "LBL_UPGRADING": ("Amélioration en cours : %s", "Upgrading: %s"), "LBL_NEXT_LEVEL": ("Niveau %d :", "Level %d:"), "LBL_DURATION": ("Durée : %s", "Duration: %s"),
    "LBL_REPAIR_MISSION": ("Mission de réparation", "Repair mission"), "LBL_REQ_FORTRESS": ("(Forteresse niv. %d requise)", "(Fortress lv. %d required)"),
    "LBL_LAB_SEALED": ("Laboratoire scellé", "Sealed laboratory"), "LBL_QUEUE": ("File de fabrication : %d / %d", "Crafting queue: %d / %d"), "LBL_DONE": ("Terminé", "Done"),
    "LBL_REQUIRES": ("Requiert", "Requires"), "LBL_LARMES": ("Larmes ancestrales : %d", "Ancestral tears: %d"), "LBL_ACTIVE": ("actif", "active"),
    "LBL_RESEARCHING": ("Recherche en cours : %s (%s)", "Researching: %s (%s)"), "LBL_NOTHING_TO_RECYCLE": ("Aucun objet recyclable (les objets équipés sont protégés).", "Nothing to recycle (equipped items are protected)."),
    "LBL_NO_RELICS": ("Vous ne possédez pas encore de relique.", "You do not own any relic yet."), "LBL_OWNED": ("Possédés : %d", "Owned: %d"),
    "LBL_DAILY_RESET": ("Nouvelles offres dans %s", "New offers in %s"), "LBL_FREE_DAILY": ("Récompense gratuite du jour", "Free daily reward"), "LBL_CLAIMED": ("Réclamé", "Claimed"),
    "LBL_LIMIT": ("Achats : %d / %d", "Purchases: %d / %d"), "LBL_IAP_PRICE_NA": ("Prix indisponible", "Price unavailable"), "LBL_PURCHASED": ("Achat effectué", "Purchased"),
    "LBL_SEASON_LOCAL": ("Saison locale (horloge de l'appareil) — fin dans %s", "Local season (device clock) — ends in %s"), "LBL_SEASON_ENDED": ("Saison terminée", "Season over"),
    "LBL_TIER": ("Palier %d / %d", "Tier %d / %d"), "LBL_TIER_SHORT": ("Palier %d", "Tier %d"), "LBL_PREMIUM_ACTIVE": ("Premium actif", "Premium active"),
    "LBL_PASS_XP_SOURCES": ("XP de pass : victoire +%d, mission quotidienne +%d, hebdomadaire +%d", "Pass XP: win +%d, daily mission +%d, weekly +%d"),
    "LBL_ACH_PROGRESS": ("Succès obtenus : %d / %d", "Achievements: %d / %d"), "LBL_RESET_IN": ("Renouvellement dans %s", "Resets in %s"),
    "LBL_THIS_WEEK": ("Cette semaine", "This week"), "LBL_EVENT_DONE": ("Récompense de la semaine obtenue.", "Weekly reward collected."), "LBL_ROTATION": ("Prochains défis locaux", "Upcoming local challenges"),
    "LBL_IN_WEEKS": ("Dans %d sem.", "In %d wk"), "LBL_EQUIPPED": ("Équipé", "Equipped"), "LBL_NOTIFICATIONS": ("Notifications", "Notifications"),
    "LBL_PROFILE": ("Profil", "Profile"), "LBL_PLAYER_LEVEL": ("Niveau du joueur", "Player level"), "LBL_CREATED": ("Profil créé le", "Profile created"),
    "LBL_VERSION": ("Version du jeu", "Game version"), "LBL_SAVE_MODE": ("Sauvegarde", "Save"), "LBL_SAVE_LOCAL": ("Locale (sur cet appareil)", "Local (this device)"),
    "LBL_LEGAL": ("Documents", "Documents"), "LBL_TAP_TO_SKIP": ("Touchez pour passer", "Tap to skip"), "LBL_FLYING": ("Volant", "Flying"),
    # ---- Conditions / requirements
    "COND_PLAYER_LEVEL": ("Niveau du joueur %d", "Player level %d"), "COND_CAMPAIGN": ("Terminer %s (%s)", "Complete %s (%s)"), "COND_FORTRESS": ("Forteresse niveau %d", "Fortress level %d"),
    "REQ_MECH_MODULE": ("Nécessite un module mécanique équipé", "Requires an equipped mechanical module"), "REQ_MASK_ITEM": ("Nécessite le Masque des Mille Visages", "Requires the Mask of a Thousand Faces"),
    "LOCK_RAID_PORTAL": ("Construisez le Portail de raid (Ma base) pour lancer des raids libres.", "Build the Raid Portal (My base) to start free raids."),
    "LOCK_BOSS": ("Battez le boss du chapitre %d pour le réaffronter.", "Defeat the chapter %d boss to fight it again."),
    "LOCK_LAB": ("Le laboratoire est verrouillé.", "The laboratory is locked."), "LOCK_ROOM": ("Salle disponible au niveau %d du laboratoire.", "Room available at laboratory level %d."),
    "LAB_LOCKED_MSG": ("Laboratoire verrouillé. Progressez dans la campagne pour débloquer la conception du King Gobelin.", "Laboratory locked. Progress through the campaign to unlock Goblin King design."),
    # ---- Errors
    "ERR_ENERGY": ("Pas assez de rage", "Not enough rage"), "ERR_ZONE": ("Déployez sur votre moitié du terrain", "Deploy on your half of the field"),
    "ERR_DECK_INCOMPLETE": ("Votre deck doit contenir 8 cartes", "Your deck must contain 8 cards"), "ERR_DECK_FULL": ("Deck complet", "Deck full"),
    "ERR_DECK_MIN": ("Le deck ne peut pas être vide", "The deck cannot be empty"), "ERR_DECK_PICK_FIRST": ("Touchez d'abord la carte du deck à remplacer", "First tap the deck card to replace"),
    "ERR_NOT_OWNED": ("Non possédé", "Not owned"), "ERR_MAX_LEVEL": ("Niveau maximum", "Maximum level"), "ERR_CARD_HALL": ("Améliorez la Salle des cartes", "Upgrade the Card Hall"),
    "ERR_GOLD": ("Or insuffisant", "Not enough gold"), "ERR_FRAGMENTS": ("Fragments insuffisants", "Not enough fragments"), "ERR_RESOURCES": ("Ressources insuffisantes", "Not enough resources"),
    "ERR_SLOT_LOCKED": ("Emplacement verrouillé", "Slot locked"), "ERR_ALREADY_OWNED": ("Déjà possédé", "Already owned"), "ERR_LAB_LOCKED": ("Laboratoire verrouillé", "Laboratory locked"),
    "ERR_MUTATION_SLOTS": ("Tous les emplacements de mutation sont utilisés", "All mutation slots are used"), "ERR_OUT_OF_BOUNDS": ("Hors des limites", "Out of bounds"),
    "ERR_ZONE_LOCKED": ("Zone verrouillée", "Zone locked"), "ERR_WRONG_ZONE": ("Ce bâtiment doit être placé dans sa zone", "This building must be placed in its zone"),
    "ERR_OVERLAP": ("Emplacement occupé", "Space occupied"), "ERR_RUIN": ("Ce bâtiment doit d'abord être réparé", "This building must be repaired first"),
    "ERR_MAX_COUNT": ("Nombre maximum atteint", "Maximum number reached"), "ERR_FORTRESS_LEVEL": ("Niveau de Forteresse insuffisant", "Fortress level too low"),
    "ERR_UPGRADING": ("Amélioration déjà en cours", "Already upgrading"), "ERR_PLAYER_LEVEL": ("Niveau du joueur insuffisant", "Player level too low"),
    "ERR_BUILDERS": ("Tous les bâtisseurs sont occupés", "All builders are busy"), "ERR_REQ_BUILDING": ("Bâtiment requis manquant", "Required building missing"),
    "ERR_ALREADY_DONE": ("Déjà effectué", "Already done"), "ERR_CONDITIONS": ("Conditions non remplies", "Conditions not met"), "ERR_ROOM_LOCKED": ("Salle verrouillée", "Room locked"),
    "ERR_BUSY": ("Une recherche est déjà en cours", "A research is already running"), "ERR_RESEARCH_HALL": ("Améliorez la Salle de recherche", "Upgrade the Research Hall"),
    "ERR_RESEARCH_REQUIRED": ("Recherche requise", "Research required"), "ERR_BUILDING_LEVEL": ("Niveau de bâtiment insuffisant", "Building level too low"),
    "ERR_QUEUE_FULL": ("File de fabrication pleine", "Crafting queue full"), "ERR_EQUIPPED": ("Objet équipé (dans une configuration)", "Item equipped (in a loadout)"),
    "ERR_NOT_RELIC": ("Ce n'est pas une relique", "Not a relic"), "ERR_IAP_UNAVAILABLE": ("Achats réels non configurés dans cette version", "Real-money purchases are not configured in this build"),
    "ERR_SOLD_OUT": ("Épuisé", "Sold out"), "ERR_PURCHASE": ("Achat impossible", "Purchase failed"), "ERR_TIER_LOCKED": ("Palier non atteint", "Tier not reached"),
    "ERR_PREMIUM_REQUIRED": ("Voie premium requise", "Premium track required"), "ERR_ALREADY_CLAIMED": ("Déjà réclamé", "Already claimed"),
    "ERR_SEASON_ENDED": ("Saison terminée", "Season over"), "ERR_HERO_DOWN": ("Le King est à terre", "The King is down"), "ERR_STUNNED": ("Le King est étourdi", "The King is stunned"),
    "ERR_COOLDOWN": ("Capacité en recharge", "Ability on cooldown"), "ERR_CHARGING": ("Capacité ultime en charge", "Ultimate charging"), "ERR_CARD": ("Carte invalide", "Invalid card"),
    "ERR_FINISHED": ("Combat terminé", "Battle over"), "ERR_NO_CARDS": ("Aucune carte dans ce défi", "No cards in this challenge"), "ERR_NAME": ("Nom trop court", "Name too short"),
    # ---- Confirmations
    "CONFIRM_UPGRADE_CARD": ("Améliorer %s ?", "Upgrade %s?"), "CONFIRM_UPGRADE_BUILDING": ("Améliorer %s ?", "Upgrade %s?"), "CONFIRM_SPEEDUP": ("Terminer immédiatement ?", "Finish now?"),
    "CONFIRM_REPAIR": ("Réparer le laboratoire ?", "Repair the laboratory?"), "CONFIRM_ZONE": ("Débloquer %s ?", "Unlock %s?"), "CONFIRM_CRAFT": ("Fabriquer %s ? Les matériaux sont consommés au lancement.", "Craft %s? Materials are consumed when crafting starts."),
    "CONFIRM_CANCEL_CRAFT": ("Annuler la fabrication ? Les matériaux seront intégralement rendus.", "Cancel crafting? Materials will be fully refunded."),
    "CONFIRM_RESEARCH": ("Lancer la recherche %s ?", "Start research %s?"), "CONFIRM_RECYCLE": ("Recycler définitivement %s ?", "Permanently recycle %s?"),
    "CONFIRM_RELIC": ("Améliorer la relique %s ?", "Upgrade relic %s?"), "CONFIRM_MUTATION": ("Débloquer la mutation %s ?", "Unlock mutation %s?"),
    "CONFIRM_BUY": ("Acheter %s ?", "Buy %s?"), "CONFIRM_PREMIUM": ("Débloquer la voie premium de la saison avec des cristaux ?", "Unlock this season's premium track with crystals?"),
    "CONFIRM_FORFEIT": ("Abandonner ce combat ? Il comptera comme une défaite.", "Forfeit this battle? It will count as a defeat."),
    "CONFIRM_RESET_SETTINGS": ("Rétablir les paramètres par défaut ?", "Restore default settings?"),
    "CONFIRM_RESET_PROFILE": ("Effacer toute votre progression sur cet appareil ?", "Erase all your progress on this device?"),
    "CONFIRM_RESET_PROFILE_2": ("Action irréversible. Confirmer la suppression ?", "This cannot be undone. Confirm deletion?"),
    # ---- Toasts / notifications
    "TOAST_LEVEL_UP": ("Niveau %d atteint !", "Level %d reached!"), "TOAST_RESEARCH_DONE": ("Recherche terminée : %s", "Research complete: %s"),
    "TOAST_BACKUP_RESTORED": ("Sauvegarde principale invalide : la copie de secours a été restaurée.", "Main save invalid: the backup copy was restored."),
    "TOAST_CARD_UPGRADED": ("%s passe au niveau %d", "%s is now level %d"), "TOAST_PICK_SWAP": ("Choisissez la carte du deck à remplacer par %s", "Pick the deck card to replace with %s"),
    "TOAST_MUTATION": ("Mutation débloquée : %s", "Mutation unlocked: %s"), "TOAST_LOADOUT_SAVED": ("Configuration enregistrée", "Loadout saved"),
    "TOAST_LOADOUT_PARTIAL": ("Configuration chargée (%d élément(s) indisponible(s))", "Loadout applied (%d unavailable element(s))"),
    "TOAST_BUILDING_DONE": ("%s : niveau %d terminé", "%s: level %d complete"), "TOAST_LAB_UNLOCKED": ("Le laboratoire est opérationnel !", "The laboratory is operational!"),
    "TOAST_NOTHING_TO_COLLECT": ("Rien à collecter pour le moment", "Nothing to collect yet"), "TOAST_CRAFTED": ("Fabrication terminée : %s", "Crafted: %s"), "TOAST_SAVED": ("Sauvegardé", "Saved"),
    "NOTIF_MISSIONS": ("%d récompense(s) de mission à réclamer", "%d mission reward(s) to claim"), "NOTIF_PASS": ("%d récompense(s) du pass", "%d pass reward(s)"),
    "NOTIF_CHESTS": ("%d coffre(s) à ouvrir", "%d chest(s) to open"), "NOTIF_FREE_DAILY": ("Récompense gratuite disponible en boutique", "Free reward available in the shop"),
    "NOTIF_CRAFT_DONE": ("Une fabrication est terminée", "A craft is finished"), "NOTIF_PRODUCTION": ("%d bâtiment(s) prêts à collecter", "%d building(s) ready to collect"),
    "NOTIF_EVENT": ("Défi local : %s", "Local challenge: %s"), "NOTIF_NONE": ("Rien de nouveau.", "Nothing new."),
    # ---- Battle FX / sounds
    "FX_ARMOR_BROKEN": ("ARMURE BRISÉE !", "ARMOR BROKEN!"), "FX_EXHAUSTED": ("ÉPUISÉ !", "EXHAUSTED!"),
    "SND_EXPLOSION": ("Explosion", "Explosion"), "SND_TELEGRAPH": ("Attaque annoncée", "Incoming attack"), "SND_TOWER_DESTROYED": ("Tour détruite", "Tower destroyed"),
    "SND_KING_ROAR": ("Rugissement", "Roar"), "SND_HIT_HEAVY": ("Coup lourd", "Heavy hit"),
    # ---- Results stats
    "STAT_TIME": ("Durée", "Time"), "STAT_UNITS": ("Unités déployées", "Units deployed"), "STAT_ABILITIES": ("Capacités du King", "King abilities"),
    "STAT_DAMAGE": ("Dégâts infligés", "Damage dealt"), "STAT_DESTROYED": ("Structures détruites", "Structures destroyed"), "STAT_LOST": ("Structures perdues", "Structures lost"),
    "STAT_WAVES": ("Vagues repoussées", "Waves cleared"), "STAT_HP": ("Points de vie", "Health"), "STAT_DMG": ("Dégâts", "Damage"), "STAT_HIT_SPEED": ("Vitesse de frappe", "Hit speed"),
    "STAT_DPS": ("Dégâts / s", "Damage / s"), "STAT_RANGE": ("Portée", "Range"), "STAT_SPEED": ("Vitesse", "Speed"), "STAT_COUNT": ("Nombre", "Count"),
    "STAT_TARGETS": ("Cibles", "Targets"), "STAT_MOVEMENT": ("Déplacement", "Movement"), "STAT_ARMOR": ("Armure", "Armor"), "STAT_RESIST": ("Résistance", "Resistance"),
    "STAT_CDR": ("Réduction de recharge", "Cooldown reduction"), "STAT_AP": ("Puissance de capacité", "Ability power"), "STAT_ATK_SPEED": ("Vitesse d'attaque", "Attack speed"),
    "STAT_ENERGY": ("Rage de départ", "Starting rage"), "STAT_WEAPON": ("Arme", "Weapon"), "STAT_MECH": ("Module mécanique", "Mechanical module"),
    "RANGE_MELEE": ("Mêlée", "Melee"), "TARGETS_STRUCTURES": ("Structures uniquement", "Structures only"), "TARGETS_AIR_GROUND": ("Air et sol", "Air and ground"), "TARGETS_GROUND": ("Sol", "Ground"),
    # ---- Filters / sorting
    "FILTER_ALL_FAMILIES": ("Toutes les familles", "All families"), "FILTER_ALL_RARITIES": ("Toutes les raretés", "All rarities"), "FILTER_ALL_TYPES": ("Tous les types", "All types"),
    "FILTER_OWNED": ("Possédées", "Owned"), "FILTER_EQUIPPED": ("Équipés / en deck", "Equipped / in deck"), "SORT_RARITY": ("Tri : rareté", "Sort: rarity"),
    "SORT_LEVEL": ("Tri : niveau", "Sort: level"), "SORT_NAME": ("Tri : nom", "Sort: name"), "SORT_COUNT": ("Tri : quantité", "Sort: quantity"),
    "INV_ITEMS": ("Équipements", "Equipment"), "INV_CARDS": ("Cartes", "Cards"), "INV_COSMETICS": ("Cosmétiques", "Cosmetics"), "INV_MATERIALS": ("Matériaux", "Materials"),
    "INV_CHESTS": ("Coffres", "Chests"), "INV_RESOURCES": ("Ressources", "Resources"),
    # ---- Hints / descriptions
    "HINT_PICK_SLOT": ("Choisissez un emplacement pour voir vos objets. Touchez un objet pour le prévisualiser sur le King et comparer les statistiques.", "Pick a slot to see your items. Tap an item to preview it on the King and compare stats."),
    "HINT_APPEARANCE": ("Les options avancées se débloquent avec votre niveau. Les mutations du laboratoire modifient aussi l'apparence.", "Advanced options unlock with your level. Laboratory mutations also change the look."),
    "HINT_COSMETICS": ("Les emotes sont utilisables en combat ; les animations de victoire, d'entrée et de défaite se jouent automatiquement.", "Emotes can be used in battle; victory, entry and defeat animations play automatically."),
    "HINT_CAPS": ("Les bonus sont plafonnés pour éviter les combinaisons abusives.", "Bonuses are capped to prevent abusive combinations."),
    "HINT_BASE": ("Glissez pour déplacer la vue · Touchez un bâtiment · Pincez ou +/- pour zoomer", "Drag to pan · Tap a building · Pinch or +/- to zoom"),
    "DESC_LOADOUTS": ("Votre King unique peut mémoriser %d configuration(s) d'équipement, de capacités et d'apparence.", "Your unique King can store %d loadout(s) of equipment, abilities and appearance."),
    "DESC_SYNERGIES": ("Les synergies s'activent selon le nombre de cartes d'une même famille dans votre deck.", "Synergies activate based on how many cards of the same family are in your deck."),
    "DESC_CHESTS": ("Les probabilités affichées sont calculées à partir des tables de butin réellement utilisées.", "Displayed odds are computed from the loot tables actually used."),
    "ODDS_CARD": ("%d carte(s) — rareté de chaque carte :", "%d card(s) — rarity of each card:"), "ODDS_ITEM": ("%d équipement(s) — rareté :", "%d item(s) — rarity:"),
    "ODDS_NOTE": ("Si aucune carte d'une rareté n'est disponible à votre niveau, le tirage passe à la rareté inférieure ; les pourcentages ci-dessus en tiennent compte.", "If no card of a rarity is available at your level, the drop falls back to the rarity below; percentages above already include this."),
    "DESC_CRAFT_RULES": ("Les matériaux sont consommés au lancement. Une fabrication ne peut pas échouer et peut être annulée avec remboursement complet.", "Materials are consumed when crafting starts. Crafting cannot fail and can be cancelled for a full refund."),
    "DESC_MUTATION_ROOM": ("Les mutations transforment le corps du King et modifient ses statistiques.", "Mutations transform the King's body and change his stats."),
    "DESC_EXPERIMENT": ("Testez votre configuration actuelle contre des mannequins ou des bots. Aucune récompense, aucune perte.", "Test your current loadout against dummies or bots. No rewards, no losses."),
    "DESC_RESEARCH": ("Niveau de recherche maximal : %d (Salle de recherche). Une recherche à la fois.", "Max research level: %d (Research Hall). One research at a time."),
    "DESC_RECYCLE": ("Transformez les objets non équipés en matériaux selon leur rareté.", "Turn unequipped items into materials based on rarity."),
    "DESC_RELICS": ("Chaque niveau de relique renforce ses effets de 10 %.", "Each relic level strengthens its effects by 10%."),
    "DESC_PASS": ("Les récompenses gratuites ne nécessitent jamais la voie premium. La voie premium s'achète avec des cristaux, gagnables en jouant.", "Free rewards never require the premium track. The premium track is bought with crystals, which can be earned by playing."),
    "DESC_PASS_SHOP": ("La voie premium du pass coûte %d cristaux (monnaie du jeu, gagnable gratuitement).", "The pass premium track costs %d crystals (in-game currency, earnable for free)."),
    "DESC_IAP_DISABLED": ("Les achats avec de l'argent réel ne sont pas configurés dans cette version : aucun paiement n'est possible ni simulé.", "Real-money purchases are not configured in this build: no payment is possible or simulated."),
    "DESC_IAP_ITEM": ("Pack de cristaux (paiement réel non configuré).", "Crystal pack (real payment not configured)."),
    "DESC_EVENTS_LOCAL": ("Défis locaux hors ligne : ils changent chaque semaine selon le calendrier de votre appareil. Aucun événement en ligne n'est actif.", "Offline local challenges: they rotate weekly using your device calendar. No online event is active."),
    "DESC_ONLINE_UNAVAILABLE": ("Le multijoueur en ligne n'est pas disponible : aucune infrastructure réseau n'existe encore. L'architecture de combat est prête à l'accueillir (simulation déterministe séparée de l'affichage).", "Online multiplayer is not available: no network infrastructure exists yet. The combat architecture is ready for it (deterministic simulation separated from rendering)."),
    "DESC_MODE_RAID": ("Attaquez une forteresse défendue par un bot : murailles, pièges et tours. Détruisez le Trône avant la fin du temps.", "Attack a bot-defended fortress: walls, traps and towers. Destroy the Throne before time runs out."),
    "DESC_MODE_DEFENSE": ("Protégez votre base contre des vagues ennemies. Vos murailles, pièges et tours de garde construits dans Ma base sont présents.", "Protect your base against enemy waves. Walls, traps and watchtowers built in My base are present."),
    "DESC_MODE_SURVIVAL": ("Des vagues de plus en plus fortes. Combien en repousserez-vous ?", "Ever stronger waves. How many can you hold?"),
    "DESC_MODE_TRAINING": ("Entraînez-vous sans risque : mannequins ou bots, rage doublée face aux mannequins.", "Practice risk-free: dummies or bots, double rage against dummies."),
    "NOTE_BOTS": ("Les bots jouent avec les mêmes règles que vous : ils ne voient pas votre main et ne reçoivent aucun bonus de statistiques selon la difficulté.", "Bots play by your rules: they cannot see your hand and get no stat bonus from difficulty."),
    "NOTE_CHALLENGE_REWARD": ("Chaque défi gagné rapporte des jetons de guerre.", "Each challenge won grants war tokens."),
    "NOTE_GRAPHICS": ("Le mode économie d'énergie force 30 FPS et la qualité basse.", "Battery saver forces 30 FPS and low quality."),
    "NOTE_NOTIFICATIONS": ("Ces réglages contrôlent les badges et alertes dans le jeu. Les notifications système Android ne sont pas encore implémentées : aucune autorisation n'est demandée.", "These settings control in-game badges and alerts. Android system notifications are not implemented yet: no permission is requested."),
    "NOTE_SAVE_LOCAL": ("La progression est enregistrée uniquement sur cet appareil (avec une copie de secours). Désinstaller le jeu efface la sauvegarde.", "Progress is stored only on this device (with a backup copy). Uninstalling the game erases the save."),
    "NOTE_ONLINE_ACCOUNT": ("Aucun compte en ligne n'existe dans cette version ; aucune donnée n'est envoyée à un serveur.", "No online account exists in this build; no data is sent to a server."),
    # ---- Challenges
    "CH_RAIDER_WILD": ("Pillards et Sauvages uniquement", "Raiders and Wild only"), "CH_DOUBLE_RAGE": ("Rage double", "Double rage"), "CH_NO_KING": ("Sans King Gobelin", "No Goblin King"),
    "CH_MAX_COST": ("Cartes de coût 4 maximum", "Cards costing 4 or less"), "CH_FORTIFIED": ("Tours ennemies renforcées (x2 PV)", "Fortified enemy towers (x2 HP)"),
    # ---- Pass tracks, loadouts, settings
    "TRACK_FREE": ("Gratuit", "Free"), "TRACK_PREMIUM": ("Premium", "Premium"),
    "LO_OFFENSIVE": ("Offensive", "Offensive"), "LO_DEFENSIVE": ("Défensive", "Defensive"), "LO_FAST": ("Rapide", "Fast"), "LO_MAGIC": ("Magique", "Magic"), "LO_CUSTOM": ("Personnalisée", "Custom"),
    "SET_QUALITY": ("Qualité graphique", "Graphics quality"), "Q_LOW": ("Basse", "Low"), "Q_MEDIUM": ("Moyenne", "Medium"), "Q_HIGH": ("Élevée", "High"),
    "SET_SHADOWS": ("Ombres", "Shadows"), "SET_PARTICLES": ("Particules", "Particles"), "SET_EFFECTS": ("Effets visuels", "Visual effects"), "SET_FPS": ("Limite d'images", "Frame limit"),
    "SET_BATTERY": ("Mode économie d'énergie", "Battery saver"), "SET_VOL_MASTER": ("Volume général", "Master volume"), "SET_VOL_MUSIC": ("Musique", "Music"),
    "SET_VOL_SFX": ("Effets sonores", "Sound effects"), "SET_VOL_VOICE": ("Voix", "Voices"), "SET_VIBRATION": ("Vibrations", "Vibration"),
    "SET_BUTTON_SIZE": ("Taille des boutons", "Button size"), "SET_LEFT_HANDED": ("Commandes inversées (gaucher)", "Mirrored controls (left-handed)"),
    "SET_CONFIRM_IMPORTANT": ("Confirmer les actions importantes", "Confirm important actions"), "SET_TEXT_SIZE": ("Taille des textes", "Text size"),
    "SET_CONTRAST": ("Contraste renforcé", "High contrast"), "SET_REDUCE_FLASH": ("Réduire les effets lumineux", "Reduce flashing effects"),
    "SET_REDUCE_SHAKE": ("Réduire les secousses de caméra", "Reduce camera shake"), "SET_LIMIT_ANIM": ("Limiter les animations", "Limit animations"),
    "SET_SOUND_INDICATORS": ("Indicateurs visuels des sons", "Visual sound indicators"), "SET_LANGUAGE": ("Langue", "Language"), "SET_TUTORIALS": ("Conseils et tutoriels", "Tips and tutorials"),
    "SET_DAMAGE_NUMBERS": ("Afficher les dégâts", "Show damage numbers"), "SET_RANGE": ("Indicateurs de portée", "Range indicators"),
    "SET_CONFIRM_SPEND": ("Confirmer les dépenses", "Confirm spending"), "SET_NOTIF_REWARDS": ("Rappels de récompenses", "Reward reminders"),
    "SET_NOTIF_EVENTS": ("Notifications d'événements", "Event notifications"), "SET_NOTIF_PROGRESS": ("Notifications de progression", "Progress notifications"),
    "SET_PLAYER_NAME": ("Nom du joueur", "Player name"),
    "SIZE_SMALL": ("Petite", "Small"), "SIZE_NORMAL": ("Normale", "Normal"), "SIZE_LARGE": ("Grande", "Large"), "SIZE_XL": ("Très grande", "Extra large"),
    # ---- Loading / tips
    "LOAD_DATA": ("Chargement des données de jeu…", "Loading game data…"), "LOAD_SAVE": ("Lecture de la sauvegarde…", "Reading save…"),
    "LOAD_TIMERS": ("Mise à jour de la forteresse…", "Updating the fortress…"), "LOAD_AUDIO": ("Préparation des sons…", "Preparing sounds…"),
    "LOAD_CARDS": ("Illustration des cartes…", "Illustrating cards…"), "LOAD_ERROR": ("Erreur de chargement (voir journal)", "Loading error (see log)"),
    "TIP_1": ("Astuce : glissez une carte sur votre moitié du terrain pour déployer vos gobelins.", "Tip: drag a card onto your half of the field to deploy goblins."),
    "TIP_2": ("Astuce : touchez le sol pour déplacer votre King Gobelin.", "Tip: tap the ground to move your Goblin King."),
    "TIP_3": ("Astuce : trois cartes d'une même famille activent une synergie.", "Tip: three cards of the same family activate a synergy."),
    "TIP_4": ("Astuce : frappez les boss pendant leurs phases d'épuisement (+50 % de dégâts).", "Tip: hit bosses while they are exhausted (+50% damage)."),
    "TIP_5": ("Astuce : vos murailles et pièges de la base défendent vraiment en mode Défense.", "Tip: your base walls and traps really defend in Defense mode."),
    "TIP_6": ("Astuce : le laboratoire se débloque après le chapitre 2, une forteresse de niveau 4 et une réparation.", "Tip: the laboratory unlocks after chapter 2, a level 4 fortress and a repair."),
    # ---- Docs
    "DOC_PRIVACY": ("Confidentialité", "Privacy"), "DOC_TERMS": ("Conditions", "Terms"), "DOC_PURCHASES": ("Achats", "Purchases"), "DOC_CONDUCT": ("Code de conduite", "Code of conduct"),
    "DOC_MINORS": ("Mineurs", "Minors"), "DOC_CREDITS": ("Crédits", "Credits"),
}

ENUMS = {
    "ABSLOT_": {"ACTIVE": ("Compétence active", "Active skill"), "DEFENSIVE": ("Compétence défensive", "Defensive skill"), "ULTIMATE": ("Capacité ultime", "Ultimate"), "PASSIVE": ("Passif", "Passive")},
    "COSKIND_": {"EMOTE": ("Emote", "Emote"), "VICTORY": ("Animation de victoire", "Victory animation"), "ENTRY": ("Effet d'entrée", "Entry effect"), "DEFEAT": ("Animation de défaite", "Defeat animation")},
    "COS_": {"EMOTE_1": ("Emote 1", "Emote 1"), "EMOTE_2": ("Emote 2", "Emote 2"), "VICTORY": ("Victoire", "Victory"), "ENTRY": ("Entrée", "Entry"), "DEFEAT": ("Défaite", "Defeat")},
    "DIFF_": {"EASY": ("Facile", "Easy"), "NORMAL": ("Normal", "Normal"), "EXPERT": ("Expert", "Expert")},
    "MODE_": {"DUEL": ("Duel", "Duel"), "RAID": ("Raid", "Raid"), "DEFENSE": ("Défense", "Defense"), "SURVIVAL": ("Survie", "Survival"), "BOSS": ("Boss", "Boss"),
              "CHALLENGE": ("Défi", "Challenge"), "TRAINING": ("Entraînement", "Training")},
    "INVK_": {"ITEM": ("Équipement", "Equipment"), "CARD": ("Carte", "Card"), "COSMETIC": ("Cosmétique", "Cosmetic"), "MATERIAL": ("Matériau", "Material"), "CHEST": ("Coffre", "Chest"), "RESOURCE": ("Ressource", "Resource")},
    "RARITY_": {"COMMON": ("Commun", "Common"), "RARE": ("Rare", "Rare"), "EPIC": ("Épique", "Epic"), "LEGENDARY": ("Légendaire", "Legendary"), "MYTHIC": ("Mythique", "Mythic"), "ANCESTRAL": ("Ancestral", "Ancestral")},
    "RES_": {"GOLD": ("Or", "Gold"), "CRYSTALS": ("Cristaux", "Crystals"), "FRAGMENTS": ("Fragments", "Shards"), "COMPONENTS": ("Composants", "Components"),
             "MUTANT_ESSENCE": ("Essence mutante", "Mutant essence"), "WAR_TOKENS": ("Jetons de guerre", "War tokens"), "ANCESTRAL": ("Matériaux ancestraux", "Ancestral materials")},
    "ROLE_": {"MELEE": ("Combattant", "Fighter"), "TANK": ("Tank", "Tank"), "RANGED": ("Distance", "Ranged"), "ASSASSIN": ("Assassin", "Assassin"), "SUPPORT": ("Soutien", "Support"),
              "SIEGE": ("Siège", "Siege"), "SWARM": ("Nuée", "Swarm"), "FLYER": ("Volant", "Flyer"), "CASTER": ("Lanceur de sorts", "Caster")},
    "SLOT_": {"HEAD": ("Tête", "Head"), "EYES": ("Yeux", "Eyes"), "TORSO": ("Torse", "Torso"), "SHOULDERS": ("Épaules", "Shoulders"), "LEFT_ARM": ("Bras gauche", "Left arm"),
              "RIGHT_ARM": ("Bras droit", "Right arm"), "HANDS": ("Mains", "Hands"), "LEGS": ("Jambes", "Legs"), "FEET": ("Pieds", "Feet"), "BACK": ("Dos", "Back"),
              "BELT": ("Ceinture", "Belt"), "AURA": ("Aura", "Aura"), "SPECIAL": ("Emplacement spécial", "Special slot")},
    "SRC_": {"STARTER": ("Départ", "Starter"), "CHEST": ("Coffres", "Chests"), "SHOP": ("Boutique", "Shop"), "CRAFT": ("Fabrication", "Crafting"), "PASS": ("Pass", "Pass"),
             "EVENT": ("Événements", "Events"), "BOSS": ("Boss", "Boss"), "ACHIEVEMENT": ("Succès", "Achievements"), "CAMPAIGN": ("Campagne", "Campaign"), "MISSION": ("Missions", "Missions")},
    "STATION_": {"FORGE": ("Forge royale", "Royal forge"), "WORKSHOP": ("Atelier", "Workshop"), "LAB": ("Laboratoire", "Laboratory")},
    "ST_": {"HP": ("PV", "HP"), "DMG": ("Dégâts", "Damage"), "ARMOR": ("Armure", "Armor"), "SPEED_PCT": ("Vitesse %", "Speed %"), "ATK_SPEED_PCT": ("Vit. d'attaque %", "Attack speed %"),
            "RANGE": ("Portée", "Range"), "ENERGY": ("Rage", "Rage"), "RESIST": ("Résistance", "Resistance"), "CDR_PCT": ("Recharge %", "Cooldown %"), "ABILITY_POWER_PCT": ("Puissance %", "Power %"), "DMG_PCT": ("Dégâts %", "Damage %")},
    "SHOP_": {"DAILY": ("Offres du jour", "Daily offers"), "CHESTS": ("Coffres", "Chests"), "WEAPONS": ("Armes", "Weapons"), "ARMORS": ("Armures", "Armor"), "ACCESSORIES": ("Accessoires", "Accessories"),
              "AURAS": ("Auras", "Auras"), "COSMETICS": ("Apparences et emotes", "Looks and emotes"), "EVENT": ("Objets d'événement", "Event items"), "CRYSTALS": ("Cristaux", "Crystals"), "PASS": ("Pass saisonnier", "Season pass")},
    "TAB_": {"CAMPAIGN": ("Campagne", "Campaign"), "RAID": ("Raids", "Raids"), "DEFENSE": ("Défense", "Defense"), "SURVIVAL": ("Survie", "Survival"), "CHALLENGES": ("Défis", "Challenges"),
             "TRAINING": ("Entraînement", "Training"), "BOSSES": ("Boss", "Bosses"), "ONLINE": ("Multijoueur", "Multiplayer"), "CARDS": ("Cartes", "Cards"), "DECK": ("Deck", "Deck"),
             "SYNERGIES": ("Synergies", "Synergies"), "EQUIPMENT": ("Équipement", "Equipment"), "APPEARANCE": ("Apparence", "Appearance"), "ABILITIES": ("Capacités", "Abilities"),
             "MUTATIONS": ("Mutations", "Mutations"), "LOADOUTS": ("Configurations", "Loadouts"), "COSMETICS": ("Cosmétiques", "Cosmetics"), "STATS": ("Statistiques", "Stats"),
             "DESIGN": ("Fabrication", "Crafting"), "MUTATION": ("Mutation", "Mutation"), "EXPERIMENT": ("Expérimentation", "Experiments"), "RESEARCH": ("Recherche", "Research"),
             "RECYCLE": ("Recyclage", "Recycling"), "RELICS": ("Reliques", "Relics"), "DAILY": ("Quotidiennes", "Daily"), "WEEKLY": ("Hebdomadaires", "Weekly"),
             "ACHIEVEMENTS": ("Succès", "Achievements"), "GRAPHICS": ("Graphismes", "Graphics"), "AUDIO": ("Audio", "Audio"), "CONTROLS": ("Commandes", "Controls"),
             "ACCESS": ("Accessibilité", "Accessibility"), "GAMEPLAY": ("Jeu", "Gameplay"), "NOTIFS": ("Notifications", "Notifications"), "ACCOUNT": ("Compte", "Account")},
    "APP_": {"FACE_SHAPE": ("Visage", "Face"), "EARS": ("Oreilles", "Ears"), "NOSE": ("Nez", "Nose"), "JAW": ("Mâchoire", "Jaw"), "TEETH": ("Dents", "Teeth"), "TUSKS": ("Défenses", "Tusks"),
             "EYES": ("Yeux", "Eyes"), "EYE_COLOR": ("Couleur des yeux", "Eye color"), "SKIN": ("Peau", "Skin"), "SCARS": ("Cicatrices", "Scars"), "PAINT": ("Peinture", "War paint"),
             "PAINT_COLOR": ("Couleur peinture", "Paint color"), "HORNS": ("Cornes", "Horns"), "CREST": ("Crête", "Crest"), "HAIR": ("Cheveux", "Hair"), "HAIR_COLOR": ("Couleur cheveux", "Hair color"),
             "HEIGHT": ("Taille", "Height"), "BULK": ("Carrure", "Build"), "MUSCLE": ("Musculature", "Muscles"), "EXPRESSION": ("Expression", "Expression"), "VOICE": ("Voix", "Voice")},
    "EFF_": {"HEAVY_EVERY": ("Frappe lourde périodique", "Periodic heavy strike"), "HERO_SPLASH": ("Attaques de zone", "Area attacks"), "HERO_ON_HIT": ("Effet à l'impact", "On-hit effect"),
             "BONUS_VS_ISOLATED": ("Bonus contre les isolés", "Bonus vs isolated"), "HERO_LIFESTEAL": ("Vol de vie", "Lifesteal"), "UNLOCK_PAINTS": ("Peintures exclusives", "Exclusive paints"),
             "ALL_STATS": ("Toutes les statistiques", "All stats"), "REVEAL": ("Révèle furtifs et pièges", "Reveals stealth and traps"), "BONUS_VS_STRUCTURES": ("Bonus contre les structures", "Bonus vs structures"),
             "REGEN": ("Régénération", "Regeneration"), "MECH_MODULE": ("Module mécanique", "Mechanical module"), "FAMILY_HP": ("PV d'une famille", "Family health"),
             "CDR_ABILITY": ("Recharge réduite", "Reduced cooldown"), "HERO_ROOT_EVERY": ("Immobilisation périodique", "Periodic root"), "ALLY_AURA": ("Aura alliée", "Ally aura"),
             "FAMILY_DMG": ("Dégâts d'une famille", "Family damage"), "LAST_STAND_EXPLOSION": ("Explosion de dernier recours", "Last stand explosion"), "THORNS": ("Épines", "Thorns")},
    "CAT_": {},
    "DESC_MODE_": {},
    "DOC_": {},
    "ODDS_": {},
    "SND_": {},
    "FAMILY_": {},
}
CAT_NAMES = {"sword": ("Épée", "Sword"), "axe": ("Hache", "Axe"), "hammer": ("Marteau", "Hammer"), "dagger": ("Dague", "Dagger"), "spear": ("Lance", "Spear"),
             "magic": ("Arme magique", "Magic weapon"), "mech": ("Mécanique", "Mechanical"), "claws": ("Griffes", "Claws"), "ranged": ("Distance", "Ranged"), "none": ("Mains nues", "Bare hands"),
             "shield": ("Bouclier", "Shield"), "helmet": ("Casque", "Helmet"), "crown": ("Couronne", "Crown"), "mask": ("Masque", "Mask"), "horns": ("Cornes", "Horns"), "lens": ("Lentilles", "Lenses"),
             "relic_eye": ("Relique (yeux)", "Relic (eyes)"), "mutation_eye": ("Mutation (yeux)", "Mutation (eyes)"), "cloth": ("Tissu", "Cloth"), "leather": ("Cuir", "Leather"),
             "plate": ("Plaques", "Plate"), "carapace": ("Carapace", "Carapace"), "pads": ("Épaulières", "Pauldrons"), "trophy": ("Trophée", "Trophy"), "gloves": ("Gants", "Gloves"),
             "relic_glove": ("Relique (mains)", "Relic (hands)"), "rings": ("Bagues", "Rings"), "boots": ("Bottes", "Boots"), "mutation": ("Mutation", "Mutation"), "bag": ("Sac", "Bag"),
             "quiver": ("Carquois", "Quiver"), "wings": ("Ailes", "Wings"), "banner": ("Bannière", "Banner"), "belt": ("Ceinture", "Belt"), "relic_belt": ("Relique (ceinture)", "Relic (belt)"),
             "aura": ("Aura", "Aura"), "relic": ("Relique", "Relic")}
FAMILY_EN = {"fire": "Fire", "ice": "Ice", "toxic": "Toxic", "mech": "Mechanical", "shadow": "Shadow", "wild": "Wild", "mystic": "Mystic", "royal": "Royal",
             "mutant": "Mutant", "air": "Air", "support": "Support", "raider": "Raiders"}


def build():
    data = json.load(open(os.path.join(ROOT, "data", "cards.json"), encoding="utf-8"))
    for fam, info in data["families"].items():
        ENUMS["FAMILY_"][fam.upper()] = (info["name"], FAMILY_EN.get(fam, info["name"]))
    for k, v in CAT_NAMES.items():
        ENUMS["CAT_"][k.upper()] = v
    out = dict(S)
    for prefix, table in ENUMS.items():
        for k, v in table.items():
            out[prefix + k] = v
    return out


def check(strings):
    missing = set()
    for dirpath, _, files in os.walk(os.path.join(ROOT, "scripts")):
        for fn in files:
            if not fn.endswith(".gd"):
                continue
            src = open(os.path.join(dirpath, fn), encoding="utf-8").read()
            for m in re.finditer(r'(?:tr|translate|Router\.error|notify)\("([A-Z][A-Z0-9_]+)"', src):
                if m.group(1) not in strings and not m.group(1).endswith("_"):
                    missing.add(m.group(1))
            for m in re.finditer(r'"((?:ERR|REQ)_[A-Z_]+)"', src):
                if m.group(1) not in strings:
                    missing.add(m.group(1))
    # dynamic keys from data
    items = json.load(open(os.path.join(ROOT, "data", "items.json"), encoding="utf-8"))
    for it in items["items"]:
        for key in ["CAT_" + it["category"].upper()] + ["SRC_" + s.upper() for s in it["sources"]] + ["EFF_" + e["type"].upper() for e in it["effects"]]:
            if key not in strings:
                missing.add(key)
    for doc in ["PRIVACY", "TERMS", "PURCHASES", "CONDUCT", "MINORS", "CREDITS"]:
        if "DOC_" + doc not in strings:
            missing.add("DOC_" + doc)
    return sorted(missing)


def main():
    strings = build()
    missing = check(strings)
    path = os.path.join(ROOT, "localization", "strings.csv")
    with open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["keys", "fr", "en"])
        for k in sorted(strings):
            w.writerow([k, strings[k][0], strings[k][1]])
    print("wrote %d strings" % len(strings))
    if missing:
        print("MISSING:", " ".join(missing))
        sys.exit(1)


if __name__ == "__main__":
    main()
