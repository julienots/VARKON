#!/usr/bin/env python3
"""VARKON content source.

This script is the single authoring source for the game data in data/*.json.
Edit the tables below, then run:

    python3 tools/gen_content.py

Gameplay code only reads data/*.json; no statistic is duplicated in GDScript.
Identifiers are stable: never rename an existing id (saves reference them).
"""
import json
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "data")

RARITIES = ["common", "rare", "epic", "legendary", "mythic", "ancestral"]

# --------------------------------------------------------------------------- CARDS
# Role templates (level-1 stats for a cost-4 unit). Cards scale them by cost and
# per-card multipliers so every unit keeps a readable identity.
ROLE = {
    "melee":    dict(hp=620, dmg=85, hit=1.1, range=0.8, speed=1.6, radius=0.45),
    "tank":     dict(hp=1900, dmg=105, hit=1.6, range=0.9, speed=1.05, radius=0.7),
    "ranged":   dict(hp=330, dmg=72, hit=1.2, range=5.2, speed=1.45, radius=0.4, proj=11),
    "assassin": dict(hp=460, dmg=150, hit=0.95, range=0.8, speed=2.2, radius=0.4),
    "support":  dict(hp=520, dmg=40, hit=1.3, range=4.0, speed=1.35, radius=0.45, proj=9),
    "siege":    dict(hp=720, dmg=170, hit=2.0, range=6.5, speed=0.95, radius=0.6, proj=8, targets="structures"),
    "swarm":    dict(hp=200, dmg=55, hit=1.0, range=0.7, speed=1.8, radius=0.35, count=3),
    "flyer":    dict(hp=470, dmg=80, hit=1.15, range=1.6, speed=1.9, radius=0.5, flying=True, air=True),
    "caster":   dict(hp=420, dmg=60, hit=1.4, range=4.8, speed=1.3, radius=0.45, proj=9),
}

FAMILIES = {
    "fire": ("Feu", "#ff6a1f"), "ice": ("Glace", "#7fd8ff"), "toxic": ("Toxique", "#7bdc3a"),
    "mech": ("Mécanique", "#b7a27a"), "shadow": ("Ombre", "#8a5cff"), "wild": ("Sauvage", "#b5652b"),
    "mystic": ("Mystique", "#4aa3ff"), "royal": ("Royale", "#ffd23f"), "mutant": ("Mutante", "#d03fd9"),
    "air": ("Aérienne", "#cfe8ff"), "support": ("Soutien", "#7fffbf"), "raider": ("Pillards", "#c9472b"),
}

# id, name, family, rarity, role, cost, mult dict, ability list, look dict, desc, unlock player level
C = []


def card(cid, name, fam, rar, role, cost, desc, ab=None, unlock=1, **kw):
    look = kw.pop("look", {})
    C.append(dict(id=cid, name=name, family=fam, rarity=rar, role=role, cost=cost, desc=desc,
                  abilities=ab or [], unlock_level=unlock, mult=kw, look=look))


# ---- Fire
card("pyrogobelin", "Pyrogobelin", "fire", "common", "ranged", 3, "Lance des projectiles enflammés qui brûlent la cible.",
     [dict(type="on_hit_burn", dps=14, dur=3.0)], look=dict(weapon="staff", acc=["flame_hair"]))
card("brulecrane", "Brûlecrâne", "fire", "rare", "melee", 4, "Ses coups appliquent une brûlure intense et durable.",
     [dict(type="on_hit_burn", dps=30, dur=4.0)], unlock=2, hp=1.05, look=dict(weapon="axe", acc=["skull_mask"]))
card("bombardier_magma", "Bombardier magma", "fire", "epic", "ranged", 5, "Projette des charges explosives qui touchent une zone.",
     [dict(type="splash", radius=1.6, pct=1.0), dict(type="on_hit_burn", dps=12, dur=2.0)], unlock=4, dmg=1.3, hit=1.5, range=0.95,
     look=dict(weapon="bomb", acc=["backpack"]))
card("gardien_braise", "Gardien de braise", "fire", "rare", "tank", 5, "Crée une protection thermique : bouclier périodique pour les alliés proches.",
     [dict(type="shield_allies", amount=160, radius=3.0, cooldown=8.0)], unlock=3, hp=0.9, look=dict(weapon="shield", acc=["ember_plates"]))
card("danseflammes", "Danseflammes", "fire", "epic", "assassin", 4, "Attaques très rapides qui enflamment l'adversaire.",
     [dict(type="on_hit_burn", dps=10, dur=2.0)], unlock=5, hit=0.55, dmg=0.6, look=dict(weapon="dual_dagger", acc=["flame_hair"]))
card("coeur_incandescent", "Cœur incandescent", "fire", "legendary", "support", 5, "Aura : +25 % de dégâts aux unités de feu proches.",
     [dict(type="aura_buff", stat="damage", pct=25, radius=4.0, family="fire")], unlock=8, hp=1.3, look=dict(weapon="orb", acc=["flame_hair", "glow"]))

# ---- Ice
card("givregriffes", "Givregriffes", "ice", "common", "melee", 3, "Ses griffes gelées ralentissent la cible.",
     [dict(type="on_hit_slow", pct=35, dur=2.0)], look=dict(weapon="claws", acc=["ice_spikes"]))
card("cryochaman", "Cryochaman", "ice", "rare", "caster", 4, "Crée périodiquement une zone gelée qui ralentit fortement les ennemis.",
     [dict(type="periodic_zone", effect="slow", radius=2.5, interval=5.0, amount=50, dur=2.5)], unlock=3, look=dict(weapon="staff", acc=["ice_crown"]))
card("briseglace", "Briseglace", "ice", "epic", "melee", 5, "Inflige +80 % de dégâts aux cibles ralenties ou gelées.",
     [dict(type="bonus_vs_slowed", mult=1.8)], unlock=5, dmg=1.25, hp=1.2, look=dict(weapon="hammer", acc=["ice_spikes"], scale=1.15))
card("sentinelle_polaire", "Sentinelle polaire", "ice", "rare", "tank", 5, "Protège ses alliés avec un bouclier de glace.",
     [dict(type="shield_allies", amount=200, radius=3.0, cooldown=10.0)], unlock=4, look=dict(weapon="shield", acc=["ice_crown"]))
card("lance_givre", "Lance-givre", "ice", "common", "ranged", 3, "Tire des carreaux de glace qui ralentissent à distance.",
     [dict(type="on_hit_slow", pct=25, dur=1.5)], unlock=2, look=dict(weapon="crossbow", acc=["hood"]))
card("gardien_blizzard", "Gardien du blizzard", "ice", "legendary", "caster", 6, "Déchaîne un blizzard : zone de contrôle qui ralentit et blesse.",
     [dict(type="periodic_zone", effect="damage_slow", radius=3.2, interval=4.0, amount=90, dur=2.0, pct=40)], unlock=9, hp=1.6,
     look=dict(weapon="staff", acc=["ice_crown", "glow"], scale=1.1))

# ---- Toxic
card("venin", "Venin", "toxic", "common", "melee", 3, "Applique un poison progressif cumulable (3 fois).",
     [dict(type="on_hit_poison", dps=12, dur=4.0)], look=dict(weapon="dagger", acc=["mushroom"]))
card("cracheur_acide", "Cracheur acide", "toxic", "rare", "ranged", 4, "Son acide réduit temporairement l'armure de la cible.",
     [dict(type="on_hit_armor_shred", amount=20, dur=4.0)], unlock=3, look=dict(weapon="bomb", acc=["mask_gas"]))
card("mycogobelin", "Mycogobelin", "toxic", "rare", "support", 4, "Répand des spores qui empoisonnent et ralentissent légèrement.",
     [dict(type="periodic_zone", effect="poison_slow", radius=2.2, interval=3.0, amount=10, dur=3.0, pct=15)], unlock=4, look=dict(weapon="staff", acc=["mushroom", "mushroom_big"]))
card("alchimiste_vert", "Alchimiste vert", "toxic", "epic", "caster", 4, "Lance des fioles cycliques : poison, puis ralentissement, puis corrosion.",
     [dict(type="alchemy_cycle", radius=1.4)], unlock=6, look=dict(weapon="flask", acc=["backpack", "goggles"]))
card("rodeur_fongique", "Rôdeur fongique", "toxic", "epic", "assassin", 4, "Entre en combat camouflé (invisible 4 s) puis empoisonne.",
     [dict(type="stealth", dur=4.0, cooldown=12.0), dict(type="on_hit_poison", dps=14, dur=3.0)], unlock=6, look=dict(weapon="dagger", acc=["hood", "mushroom"]))
card("colosse_putride", "Colosse putride", "toxic", "legendary", "tank", 7, "Très résistant, il émet une aura toxique autour de lui.",
     [dict(type="periodic_zone", effect="poison", radius=2.4, interval=1.5, amount=18, dur=2.0)], unlock=10, hp=1.3,
     look=dict(weapon="club", acc=["mushroom_big", "boils"], scale=1.45))

# ---- Mechanical
card("ferrailleur", "Ferrailleur", "mech", "rare", "support", 4, "Construit une tourelle temporaire toutes les 12 s.",
     [dict(type="build_turret", cooldown=12.0, hp=300, dmg=40, hit=0.8, range=5.0, life=14.0)], unlock=3, look=dict(weapon="wrench", acc=["goggles", "backpack"]))
card("boulon", "Boulon", "mech", "common", "ranged", 3, "Tireur mécanique à cadence rapide.", [], hit=0.7, dmg=0.6, look=dict(weapon="blaster", acc=["goggles"]))
card("broyeur", "Broyeur", "mech", "epic", "melee", 5, "Ses mâchoires mécaniques infligent des dégâts de zone.",
     [dict(type="splash", radius=1.3, pct=0.8)], unlock=5, hp=1.4, look=dict(weapon="saw", acc=["metal_plates"], scale=1.2))
card("mecanicien_royal", "Mécanicien royal", "mech", "epic", "support", 4, "Répare les unités mécaniques et les structures alliées.",
     [dict(type="repair", amount=70, interval=2.0, range=4.0, filter="mech_or_structure")], unlock=6, look=dict(weapon="wrench", acc=["goggles", "crown_small"]))
card("scie_gobelin", "Scie-gobelin", "mech", "rare", "melee", 4, "Spécialiste des défenses : +120 % de dégâts aux structures.",
     [dict(type="bonus_vs_structures", mult=2.2)], unlock=4, targets="structures", speed=1.2, look=dict(weapon="saw", acc=["goggles"]))
card("titan_vapeur", "Titan à vapeur", "mech", "legendary", "tank", 7, "Unité lourde : chaque coup repousse les adversaires.",
     [dict(type="knockback_on_hit", force=1.6), dict(type="splash", radius=1.2, pct=0.6)], unlock=10, hp=1.25, dmg=1.4,
     look=dict(weapon="piston", acc=["metal_plates", "chimney"], scale=1.5))

# ---- Shadow
card("ombre_lame", "Ombre-lame", "shadow", "rare", "assassin", 4, "Se téléporte sur une cible éloignée (portée 7, recharge 9 s).",
     [dict(type="teleport_strike", range=7.0, cooldown=9.0, mult=1.5)], unlock=3, look=dict(weapon="dual_dagger", acc=["hood"]))
card("saboteur", "Saboteur", "shadow", "epic", "assassin", 4, "Cible les défenses et les neutralise 4 s à chaque contact.",
     [dict(type="disable_structure", dur=4.0, cooldown=8.0)], unlock=5, targets="structures", dmg=0.6, look=dict(weapon="bomb", acc=["hood", "goggles"]))
card("traqueur_nocturne", "Traqueur nocturne", "shadow", "rare", "assassin", 4, "Devient indétectable 3 s toutes les 10 s.",
     [dict(type="stealth", dur=3.0, cooldown=10.0)], unlock=4, look=dict(weapon="dagger", acc=["hood"]))
card("spectrogobelin", "Spectrogobelin", "shadow", "epic", "caster", 4, "Crée un leurre qui attire les attaques ennemies.",
     [dict(type="decoy", hp=350, life=6.0, cooldown=9.0)], unlock=6, look=dict(weapon="orb", acc=["hood", "glow"]))
card("faucheur_obscur", "Faucheur obscur", "shadow", "legendary", "assassin", 5, "Inflige +90 % de dégâts aux ennemis isolés.",
     [dict(type="bonus_vs_isolated", mult=1.9, radius=2.5)], unlock=9, hp=1.3, look=dict(weapon="scythe", acc=["hood", "glow"]))
card("maitre_ombres", "Maître des ombres", "shadow", "mythic", "caster", 6, "Rend périodiquement furtifs (3 s) les alliés proches.",
     [dict(type="stealth_aura", radius=3.5, dur=3.0, cooldown=9.0)], unlock=12, hp=1.6, look=dict(weapon="staff", acc=["hood", "glow", "cape"]))

# ---- Wild
card("croquefer", "Croquefer", "wild", "common", "tank", 4, "Combattant résistant et bon marché.", [], hp=0.85, look=dict(weapon="club", acc=["fur"], scale=1.2))
card("bondisseur", "Bondisseur", "wild", "rare", "melee", 3, "Franchit les murailles d'un bond.", [dict(type="jump_walls")], unlock=3, speed=1.25, look=dict(weapon="claws", acc=["fur"]))
card("ragecornes", "Ragecornes", "wild", "rare", "melee", 4, "Charge : son premier coup après une course inflige x2,5 et repousse.",
     [dict(type="charge", min_dist=3.0, mult=2.5, force=1.5)], unlock=2, hp=1.2, look=dict(weapon="horns", acc=["fur", "horns_big"]))
card("hurleur", "Hurleur", "wild", "epic", "support", 4, "Ses hurlements renforcent la cadence des alliés sauvages proches (+30 %).",
     [dict(type="aura_buff", stat="attack_speed", pct=30, radius=4.0, family="wild")], unlock=5, look=dict(weapon="horn", acc=["fur"]))
card("brise_os", "Brise-os", "wild", "epic", "melee", 5, "Coups dévastateurs qui ignorent 50 % de l'armure.",
     [dict(type="armor_pierce", pct=50)], unlock=6, dmg=1.6, hit=1.4, look=dict(weapon="bone_club", acc=["fur"], scale=1.25))
card("alpha_sauvage", "Alpha sauvage", "wild", "legendary", "tank", 6, "Appelle deux loups gobelins et renforce sa meute (+20 % dégâts).",
     [dict(type="summon", unit="loup_gobelin", count=2, cooldown=14.0, on_deploy=True),
      dict(type="aura_buff", stat="damage", pct=20, radius=4.0, family="wild")], unlock=9, look=dict(weapon="axe", acc=["fur", "horns_big", "cape"], scale=1.3))

# ---- Mystic
card("runiste", "Runiste", "mystic", "rare", "caster", 4, "Pose des runes qui explosent au contact d'un ennemi.",
     [dict(type="rune_trap", dmg=160, radius=1.5, cooldown=6.0)], unlock=3, look=dict(weapon="staff", acc=["runes"]))
card("chronomancien", "Chronomancien", "mystic", "epic", "caster", 5, "Ralentit le temps dans une zone : vitesse et cadence ennemies -40 %.",
     [dict(type="periodic_zone", effect="timewarp", radius=3.0, interval=7.0, amount=40, dur=3.5)], unlock=6, look=dict(weapon="hourglass", acc=["runes", "glow"]))
card("porteur_faille", "Porteur de faille", "mystic", "legendary", "support", 5, "Ouvre une faille : les alliés terrestres qui y entrent sont projetés 6 m plus loin.",
     [dict(type="rift", distance=6.0, radius=1.2, life=12.0)], unlock=9, look=dict(weapon="orb", acc=["runes", "glow"]))
card("oracle_gobelin", "Oracle gobelin", "mystic", "epic", "support", 4, "Si votre camp est en infériorité numérique, alliés proches +30 % dégâts.",
     [dict(type="underdog_aura", pct=30, radius=4.5)], unlock=7, look=dict(weapon="staff", acc=["blindfold", "runes"]))
card("tisseur_energie", "Tisseur d'énergie", "mystic", "mythic", "caster", 5, "Redirige la magie : durée des altérations sur les alliés proches -50 %.",
     [dict(type="cleanse_aura", pct=50, radius=4.0)], unlock=11, look=dict(weapon="orb", acc=["runes", "glow", "cape"]))
card("gardien_ancestral", "Gardien ancestral", "mystic", "ancestral", "tank", 7, "Protège une zone avec un puissant bouclier régénéré.",
     [dict(type="shield_allies", amount=420, radius=4.0, cooldown=9.0)], unlock=14, hp=1.4, look=dict(weapon="shield", acc=["runes", "glow", "crown_small"], scale=1.45))

# ---- Royal
card("garde_trone", "Garde du trône", "royal", "rare", "tank", 4, "Protège le King Gobelin : absorbe 40 % des dégâts qu'il subit à proximité.",
     [dict(type="protect_king", pct=40, radius=3.5)], unlock=4, hp=0.8, look=dict(weapon="halberd", acc=["helm_royal"]))
card("porte_etendard", "Porte-étendard", "royal", "epic", "support", 4, "Renforce armure (+20) et dégâts (+10 %) des alliés proches.",
     [dict(type="aura_buff", stat="armor", flat=20, radius=4.0), dict(type="aura_buff", stat="damage", pct=10, radius=4.0)], unlock=5, look=dict(weapon="banner", acc=["helm_royal"]))
card("executeur_royal", "Exécuteur royal", "royal", "epic", "melee", 5, "Achève les cibles affaiblies : x3 sous 30 % de vie.",
     [dict(type="execute", threshold=0.3, mult=3.0)], unlock=6, look=dict(weapon="axe_big", acc=["hood_red"], scale=1.15))
card("champion_royaume", "Champion du royaume", "royal", "legendary", "melee", 5, "Polyvalent, il gagne +12 % de dégâts par élimination (max 5).",
     [dict(type="stacking_on_kill", pct=12, max=5)], unlock=8, hp=1.5, look=dict(weapon="sword", acc=["helm_royal", "cape"], scale=1.15))
card("heraut_guerre", "Héraut de guerre", "royal", "rare", "support", 3, "Coordonne l'équipe : +20 % de vitesse de déplacement et d'attaque autour de lui.",
     [dict(type="aura_buff", stat="speed", pct=20, radius=4.0), dict(type="aura_buff", stat="attack_speed", pct=20, radius=4.0)], unlock=4, look=dict(weapon="horn", acc=["helm_royal"]))
card("protecteur_ancestral", "Protecteur ancestral", "royal", "mythic", "tank", 6, "Réduit de 30 % les dégâts subis par les unités proches.",
     [dict(type="damage_reduction_aura", pct=30, radius=3.5)], unlock=12, hp=1.2, look=dict(weapon="shield", acc=["helm_royal", "glow", "cape"], scale=1.35))

# ---- Mutant
card("tentaculaire", "Tentaculaire", "mutant", "rare", "melee", 4, "Immobilise sa cible 1,5 s toutes les 6 s.",
     [dict(type="root_on_hit", dur=1.5, cooldown=6.0)], unlock=4, look=dict(weapon="tentacle", acc=["tentacles"]))
card("machoire_geante", "Mâchoire géante", "mutant", "epic", "melee", 5, "Morsure dévastatrice à très courte portée.", [], unlock=5, dmg=2.0, hit=1.7, range=0.7,
     look=dict(weapon="none", acc=["big_jaw"], scale=1.3))
card("epineux", "Épineux", "mutant", "rare", "tank", 4, "Renvoie 30 % des dégâts de mêlée subis.", [dict(type="thorns", pct=30)], unlock=3, hp=0.85, look=dict(weapon="claws", acc=["spikes"]))
card("devoreur", "Dévoreur", "mutant", "epic", "melee", 5, "Récupère 35 % des dégâts infligés en santé.", [dict(type="lifesteal", pct=35)], unlock=6, hp=1.2,
     look=dict(weapon="claws", acc=["big_jaw", "boils"], scale=1.2))
card("mutagene", "Mutagène", "mutant", "legendary", "support", 4, "Amplifie les capacités des alliés proches (+35 % de puissance).",
     [dict(type="aura_buff", stat="ability_power", pct=35, radius=4.0)], unlock=9, look=dict(weapon="flask", acc=["boils", "glow"]))
card("abomination_royale", "Abomination royale", "mutant", "mythic", "tank", 8, "Sous 50 % de vie, entre en frénésie : +60 % dégâts, +40 % vitesse.",
     [dict(type="phase_change", threshold=0.5, damage_pct=60, speed_pct=40, atk_pct=30)], unlock=13, hp=1.5, dmg=1.3,
     look=dict(weapon="claws", acc=["tentacles", "spikes", "crown_small"], scale=1.7))

# ---- Air
card("aile_griffe", "Aile-griffe", "air", "common", "flyer", 3, "Attaque depuis les airs, hors de portée de la mêlée.", [], look=dict(weapon="claws", acc=["wings"]))
card("bombardier_gobelin", "Bombardier gobelin", "air", "epic", "flyer", 5, "Survole le champ et largue des explosifs sur les défenses.",
     [dict(type="splash", radius=1.6, pct=1.0)], unlock=6, targets="structures", air=False, dmg=2.2, hit=2.0, range=0.8, look=dict(weapon="bomb", acc=["wings", "goggles"]))
card("eclaireur_vents", "Éclaireur des vents", "air", "rare", "flyer", 3, "Révèle les unités furtives et pièges dans un rayon de 5.",
     [dict(type="reveal", radius=5.0)], unlock=4, hp=0.7, dmg=0.6, speed=1.3, look=dict(weapon="spear", acc=["wings"]))
card("fauconneur", "Fauconneur gobelin", "air", "epic", "ranged", 5, "Dirige des faucons : invoque 2 faucons volants toutes les 10 s.",
     [dict(type="summon", unit="faucon", count=2, cooldown=10.0, on_deploy=True)], unlock=7, look=dict(weapon="crossbow", acc=["feathers"]))
card("ravageur_celeste", "Ravageur céleste", "air", "legendary", "flyer", 6, "Unité aérienne offensive qui frappe en zone.",
     [dict(type="splash", radius=1.3, pct=0.7)], unlock=10, hp=1.8, dmg=1.6, look=dict(weapon="spear", acc=["wings", "helm_royal"], scale=1.3))
card("gardien_cimes", "Gardien des cimes", "air", "epic", "flyer", 5, "Protège les unités aériennes proches (bouclier 180).",
     [dict(type="shield_allies", amount=180, radius=4.0, cooldown=8.0, filter="flying")], unlock=7, hp=1.6, look=dict(weapon="shield", acc=["wings"]))

# ---- Support
card("medecin_guerre", "Médecin de guerre", "support", "common", "support", 3, "Soigne l'allié le plus blessé (75 PV / 2 s).",
     [dict(type="heal_ally", amount=75, interval=2.0, range=4.5)], look=dict(weapon="flask", acc=["backpack"]))
card("porte_bouclier", "Porte-bouclier", "support", "common", "tank", 3, "Absorbe une partie des dégâts : bouclier pour lui et ses voisins.",
     [dict(type="shield_allies", amount=120, radius=2.0, cooldown=9.0)], hp=0.7, look=dict(weapon="shield", acc=["metal_plates"]))
card("tambour_guerre", "Tambour de guerre", "support", "rare", "support", 4, "Le rythme du tambour augmente l'attaque des alliés proches (+20 %).",
     [dict(type="aura_buff", stat="damage", pct=20, radius=4.0)], unlock=3, look=dict(weapon="drum", acc=["fur"]))
card("fournisseur", "Fournisseur", "support", "rare", "support", 3, "Tant qu'il vit, la rage (énergie) se régénère 15 % plus vite.",
     [dict(type="energy_boost", pct=15)], unlock=5, hp=0.9, dmg=0.5, look=dict(weapon="none", acc=["backpack", "sack"]))
card("ingenieur_terrain", "Ingénieur de terrain", "support", "rare", "support", 4, "Répare les structures alliées (90 PV / 2 s).",
     [dict(type="repair", amount=90, interval=2.0, range=5.0, filter="structure")], unlock=4, look=dict(weapon="wrench", acc=["goggles", "helmet_work"]))
card("chamane_tribu", "Chamane de tribu", "support", "legendary", "caster", 5, "Amplifie les synergies : alliés de familles en synergie +25 % dégâts.",
     [dict(type="aura_buff", stat="damage", pct=25, radius=5.0, filter="synergy")], unlock=9, look=dict(weapon="staff", acc=["feathers", "fur"]))

# ---- Raiders (10 additional families units)
card("pillard", "Pillards", "raider", "common", "swarm", 2, "Trois pillards rapides et bon marché.", [], look=dict(weapon="dagger", acc=["bandana"]))
card("frondeur", "Frondeur", "raider", "common", "ranged", 2, "Tireur à la fronde, fragile mais économique.", [], hp=0.8, dmg=0.8, look=dict(weapon="sling", acc=["bandana"]))
card("kamikaze", "Gobelin kamikaze", "raider", "rare", "swarm", 2, "Fonce sur les défenses et explose à sa mort.",
     [dict(type="death_explosion", dmg=260, radius=1.8)], unlock=2, count=1, hp=1.2, targets="structures", speed=1.3, look=dict(weapon="bomb", acc=["bandana", "barrel"]))
card("chef_pillard", "Chef pillard", "raider", "epic", "melee", 5, "Appelle 2 pillards toutes les 9 s.",
     [dict(type="summon", unit="pillard_mini", count=2, cooldown=9.0, on_deploy=False)], unlock=5, hp=1.4, look=dict(weapon="sword", acc=["bandana", "cape"], scale=1.15))
card("catapulte_gobeline", "Catapulte gobeline", "raider", "epic", "siege", 5, "Arme de siège longue portée qui pilonne les structures en zone.",
     [dict(type="splash", radius=1.5, pct=1.0)], unlock=6, look=dict(weapon="catapult", acc=["bandana"], scale=1.2))
card("porte_torche", "Porte-torche", "raider", "common", "melee", 3, "Incendie les défenses : brûlure x2 sur les structures.",
     [dict(type="on_hit_burn", dps=16, dur=3.0, structure_mult=2.0)], unlock=2, look=dict(weapon="torch", acc=["bandana"]))
card("voleur", "Voleur", "raider", "rare", "assassin", 3, "Chaque coup sur une structure vole 0,25 point de rage.",
     [dict(type="energy_steal", amount=0.25)], unlock=4, dmg=0.7, look=dict(weapon="dagger", acc=["hood", "sack"]))
card("berserker", "Berserker", "raider", "epic", "melee", 4, "Plus il est blessé, plus il frappe fort (jusqu'à +100 %).",
     [dict(type="enrage", max_pct=100)], unlock=6, look=dict(weapon="dual_axe", acc=["bandana", "scars"]))
card("trappeur", "Trappeur", "raider", "rare", "ranged", 4, "Pose des pièges qui immobilisent 2 s les ennemis terrestres.",
     [dict(type="trap_layer", root=2.0, dmg=60, cooldown=7.0)], unlock=4, look=dict(weapon="crossbow", acc=["fur", "sack"]))
card("chevaucheur_loup", "Chevaucheur de loup", "raider", "legendary", "melee", 5, "Cavalerie rapide qui charge et frappe en premier.",
     [dict(type="charge", min_dist=3.0, mult=2.0, force=1.0)], unlock=8, speed=1.5, hp=1.5, look=dict(weapon="spear", acc=["wolf_mount"], scale=1.2))

# Tokens (not collectible): summoned units
TOKENS = [
    dict(id="loup_gobelin", name="Loup gobelin", family="wild", role="melee", hp=320, dmg=60, hit=0.9, range=0.7, speed=2.2, radius=0.4, look=dict(weapon="none", acc=["wolf_body"])),
    dict(id="faucon", name="Faucon", family="air", role="flyer", hp=120, dmg=35, hit=0.8, range=0.8, speed=2.6, radius=0.3, flying=True, air=True, look=dict(weapon="none", acc=["bird_body"]), life=12.0),
    dict(id="pillard_mini", name="Pillard", family="raider", role="melee", hp=200, dmg=50, hit=1.0, range=0.7, speed=1.8, radius=0.35, look=dict(weapon="dagger", acc=["bandana"])),
]

RARITY_COST_ADJ = {"common": 1.0, "rare": 1.04, "epic": 1.08, "legendary": 1.12, "mythic": 1.16, "ancestral": 1.2}


def build_cards():
    out = []
    for c in C:
        r = dict(ROLE[c["role"]])
        m = c["mult"]
        scale = (c["cost"] / 4.0) ** 0.95 * RARITY_COST_ADJ[c["rarity"]]
        count = m.get("count", r.get("count", 1))
        if count > 1:
            scale /= count ** 0.85
        st = dict(
            hp=round(r["hp"] * scale * m.get("hp", 1.0)),
            dmg=round(r["dmg"] * scale * m.get("dmg", 1.0)),
            hit=round(r["hit"] * m.get("hit", 1.0), 2),
            range=round(r["range"] * m.get("range", 1.0), 2),
            speed=round(r["speed"] * m.get("speed", 1.0), 2),
            radius=r["radius"] * c["look"].get("scale", 1.0),
            proj=r.get("proj", 0),
            count=count,
            flying=m.get("flying", r.get("flying", False)),
            air=m.get("air", r.get("air", r.get("proj", 0) > 0)),
            targets=m.get("targets", r.get("targets", "any")),
            armor=m.get("armor", 25 if c["role"] == "tank" else 0),
        )
        out.append(dict(id=c["id"], name=c["name"], family=c["family"], rarity=c["rarity"], role=c["role"],
                        cost=c["cost"], desc=c["desc"], abilities=c["abilities"], unlock_level=c["unlock_level"],
                        stats=st, look=c["look"]))
    tokens = []
    for t in TOKENS:
        st = {k: t[k] for k in ("hp", "dmg", "hit", "range", "speed", "radius")}
        st.update(proj=0, count=1, flying=t.get("flying", False), air=t.get("air", False), targets="any", armor=0)
        tokens.append(dict(id=t["id"], name=t["name"], family=t["family"], rarity="common", role=t["role"], cost=0,
                           desc="Invocation", abilities=[], unlock_level=99, stats=st, look=t["look"], token=True,
                           life=t.get("life", 0)))
    return out, tokens


# --------------------------------------------------------------------------- ITEMS (King Gobelin)
SLOTS = [
    ("head", "Tête"), ("eyes", "Yeux"), ("torso", "Torse"), ("shoulders", "Épaules"), ("left_arm", "Bras gauche"),
    ("right_arm", "Bras droit"), ("hands", "Mains"), ("legs", "Jambes"), ("feet", "Pieds"), ("back", "Dos"),
    ("belt", "Ceinture"), ("aura", "Aura"), ("special", "Emplacement spécial"),
]
# Slot unlock: (condition type, value)
SLOT_UNLOCK = {
    "head": None, "torso": None, "right_arm": None, "legs": None, "feet": None,
    "hands": ("player_level", 2), "left_arm": ("player_level", 3), "shoulders": ("player_level", 4),
    "belt": ("campaign", "c1m8"), "back": ("campaign", "c2m4"), "eyes": ("campaign", "c2m8"),
    "aura": ("player_level", 8), "special": ("campaign", "c3m4"),
}

ITEMS = []


def item(iid, name, slot, cat, rar, desc, stats=None, vis=None, src=None, effects=None, cosmetic=False, req=None):
    ITEMS.append(dict(id=iid, name=name, slot=slot, category=cat, rarity=rar, desc=desc, stats=stats or {},
                      visual=vis or {}, sources=src or ["chest"], effects=effects or [], cosmetic=cosmetic,
                      requires=req or {}))


# Weapons (right arm) — category drives the attack style in combat
W = "right_arm"
item("w_rusty_blade", "Lame rouillée", W, "sword", "common", "Une vieille épée gobeline. Fiable.", dict(dmg=10), dict(mesh="sword", color="#8c7a66", metal=0.6), ["starter"])
item("w_bone_axe", "Hache d'os", W, "axe", "common", "Hache taillée dans un os de troll.", dict(dmg=16, atk_speed_pct=-5), dict(mesh="axe", color="#e8dcc0", metal=0.0), ["chest", "shop"])
item("w_club", "Gourdin clouté", W, "hammer", "common", "Simple, lourd, efficace.", dict(dmg=18, atk_speed_pct=-8), dict(mesh="hammer", color="#6b4a2b", metal=0.1), ["chest"])
item("w_shiv", "Surin", W, "dagger", "common", "Petite lame rapide.", dict(dmg=6, atk_speed_pct=12), dict(mesh="dagger", color="#a0a0a0", metal=0.8), ["chest"])
item("w_pike", "Pique de garde", W, "spear", "common", "Garde les ennemis à distance.", dict(dmg=10, range=0.6), dict(mesh="spear", color="#7a6a55", metal=0.5), ["chest", "shop"])
item("w_brise_fer", "Brise-Fer", W, "hammer", "rare", "Marteau massif qui favorise les attaques lourdes.", dict(dmg=34, atk_speed_pct=-12), dict(mesh="hammer_big", color="#5c5f66", metal=0.9), ["chest", "shop", "craft"])
item("w_crocs_noirs", "Crocs Noirs", W, "dagger", "rare", "Dagues jumelles adaptées aux attaques rapides.", dict(dmg=14, atk_speed_pct=25), dict(mesh="dual_dagger", color="#1d1b22", metal=0.8, emit="#6b2bff"), ["chest", "craft"])
item("w_fendoir_royal", "Fendoir Royal", W, "axe", "epic", "Hache imposante destinée aux coups puissants.", dict(dmg=42, atk_speed_pct=-6), dict(mesh="axe_big", color="#d9b44a", metal=1.0), ["chest", "shop", "craft"])
item("w_epine_arcanique", "Épine Arcanique", W, "magic", "epic", "Arme magique : attaques à distance, +20 % de puissance de capacité.", dict(dmg=24, range=3.5, ability_power_pct=20), dict(mesh="staff", color="#3a2a5a", metal=0.2, emit="#58a6ff"), ["chest", "craft", "pass"])
item("w_machoire_acier", "Mâchoire d'Acier", W, "mech", "epic", "Arme mécanique : une morsure sur quatre étourdit.", dict(dmg=30), dict(mesh="mech_jaw", color="#8d8f94", metal=1.0, emit="#ff8a2b"), ["craft", "chest"], [dict(type="heavy_every", n=4, mult=1.6, stun=0.6)])
item("w_lance_tempete", "Lance-tempête", W, "spear", "rare", "Lance électrifiée.", dict(dmg=22, range=0.8), dict(mesh="spear", color="#5b6a8a", metal=0.8, emit="#9ad7ff"), ["chest", "shop"])
item("w_arbalete", "Arbalète gobeline", W, "ranged", "rare", "Tir à distance précis.", dict(dmg=18, range=4.0), dict(mesh="crossbow", color="#6b4a2b", metal=0.3), ["chest", "craft"])
item("w_canon_main", "Canon à main", W, "mech", "legendary", "Arme mécanique explosive à distance.", dict(dmg=40, range=4.0, atk_speed_pct=-10), dict(mesh="blaster", color="#7a7f88", metal=1.0, emit="#ffb347"), ["craft", "chest"], [dict(type="hero_splash", radius=1.4, pct=0.6)])
item("w_griffes_rage", "Griffes de rage", W, "claws", "rare", "Griffes rapides et cruelles.", dict(dmg=16, atk_speed_pct=18), dict(mesh="claws", color="#c4c4c4", metal=0.9), ["chest"])
item("w_lame_braise", "Lame de braise", W, "sword", "epic", "Épée incandescente : les coups brûlent.", dict(dmg=30), dict(mesh="sword", color="#3a2015", metal=0.7, emit="#ff5a1f"), ["chest", "event"], [dict(type="hero_on_hit", effect="burn", dps=20, dur=3.0)])
item("w_hache_givre", "Hache de givre", W, "axe", "epic", "Hache glacée qui ralentit.", dict(dmg=32), dict(mesh="axe", color="#bfe8ff", metal=0.9, emit="#7fd8ff"), ["chest", "event"], [dict(type="hero_on_hit", effect="slow", pct=30, dur=2.0)])
item("w_faux_ombre", "Faux de l'ombre", W, "axe", "legendary", "Faux maudite : +40 % contre les ennemis isolés.", dict(dmg=46), dict(mesh="scythe", color="#221a2e", metal=0.6, emit="#8a5cff"), ["pass", "chest"], [dict(type="bonus_vs_isolated", mult=1.4)])
item("w_marteau_roi", "Marteau du Roi", W, "hammer", "legendary", "Marteau royal : chaque coup frappe en zone.", dict(dmg=58, atk_speed_pct=-10), dict(mesh="hammer_big", color="#f0c64a", metal=1.0, emit="#fff2a8"), ["craft", "shop"], [dict(type="hero_splash", radius=1.6, pct=0.5)])
item("w_croc_mythique", "Croc du Dévoreur", W, "claws", "mythic", "Arraché au Dévoreur Mutant : vol de vie 12 %.", dict(dmg=50, atk_speed_pct=15), dict(mesh="claws", color="#4a1030", metal=0.4, emit="#ff3d9a"), ["boss"], [dict(type="hero_lifesteal", pct=12)])
item("w_lame_ancestrale", "Lame des Ancêtres", W, "sword", "ancestral", "Lame légendaire des premiers rois gobelins.", dict(dmg=70, atk_speed_pct=10, hp=200), dict(mesh="sword_big", color="#e8f7ff", metal=1.0, emit="#3ff0e0"), ["achievement"])
item("w_epee_parade", "Épée de parade", W, "sword", "rare", "Cosmétique : une lame d'apparat, sans bonus.", {}, dict(mesh="sword", color="#ffd86b", metal=1.0, emit="#fff6c8"), ["pass", "shop"], cosmetic=True)

# Left arm: shields / off-hand
L = "left_arm"
item("l_buckler", "Rondache", L, "shield", "common", "Petit bouclier de bois.", dict(armor=6), dict(mesh="shield_round", color="#7a5230"), ["starter", "chest"])
item("l_plank_shield", "Bouclier de planches", L, "shield", "common", "Planches clouées.", dict(armor=9, speed_pct=-3), dict(mesh="shield_square", color="#8a6a40"), ["chest", "shop"])
item("l_iron_shield", "Pavois de fer", L, "shield", "rare", "Bouclier épais.", dict(armor=16, hp=120, speed_pct=-5), dict(mesh="shield_tower", color="#6d7076", metal=0.9), ["chest", "craft"])
item("l_claw_off", "Griffe secondaire", L, "claws", "rare", "Une seconde griffe pour frapper plus vite.", dict(atk_speed_pct=10, dmg=6), dict(mesh="claws", color="#c4c4c4", metal=0.9), ["chest"])
item("l_rune_shield", "Égide runique", L, "shield", "epic", "Bouclier gravé : +résistance.", dict(armor=14, resist=15), dict(mesh="shield_round", color="#2f3a60", metal=0.8, emit="#58a6ff"), ["craft", "pass"])
item("l_royal_shield", "Bouclier royal", L, "shield", "legendary", "Bouclier de la garde du trône.", dict(armor=24, hp=250), dict(mesh="shield_tower", color="#d9b44a", metal=1.0, emit="#fff2a8"), ["craft", "shop"])
item("l_griffe_traqueur", "Griffe du Traqueur", L, "claws", "epic", "Relique : +30 % de dégâts contre les ennemis isolés.", dict(dmg=10), dict(mesh="claws", color="#2a2233", metal=0.7, emit="#8a5cff"), ["chest", "event"], [dict(type="bonus_vs_isolated", mult=1.3)])

# Head
H = "head"
item("h_leather_cap", "Bonnet de cuir", H, "helmet", "common", "Protège un peu les oreilles.", dict(armor=3), dict(mesh="cap", color="#6b4a2b"), ["starter"])
item("h_iron_helm", "Casque de fer", H, "helmet", "common", "Casque cabossé.", dict(armor=6, hp=60), dict(mesh="helm", color="#7b7f86", metal=0.9), ["chest", "shop"])
item("h_bone_crown", "Couronne d'os", H, "crown", "rare", "Faite de dents d'ennemis.", dict(hp=120, dmg=4), dict(mesh="crown_spiky", color="#e8dcc0"), ["chest", "craft"])
item("h_war_mask", "Masque de guerre", H, "mask", "rare", "Terrifie l'adversaire.", dict(dmg=8, armor=4), dict(mesh="mask", color="#8c2a1c"), ["chest", "shop"])
item("h_ram_horns", "Cornes de bélier", H, "horns", "rare", "Ornement imposant.", dict(hp=80), dict(mesh="horns_ram", color="#d8c8a8"), ["chest"])
item("h_gear_helm", "Casque à engrenages", H, "helmet", "epic", "Casque mécanique avec visière.", dict(armor=12, cdr_pct=5), dict(mesh="helm_gear", color="#8d8f94", metal=1.0, emit="#ff8a2b"), ["craft"])
item("h_royal_crown", "Couronne royale", H, "crown", "epic", "La couronne d'un vrai King.", dict(hp=200, ability_power_pct=10), dict(mesh="crown", color="#f0c64a", metal=1.0), ["shop", "pass"])
item("h_masque_mille", "Masque des Mille Visages", H, "mask", "legendary", "Relique : débloque trois variantes de peintures de guerre exclusives.", dict(resist=10), dict(mesh="mask", color="#2b2b2b", metal=0.3, emit="#d03fd9"), ["event", "chest"], [dict(type="unlock_paints", paints=["mille_1", "mille_2", "mille_3"])])
item("h_couronne_dernier_roi", "Couronne du Dernier Roi", H, "crown", "ancestral", "Récompense ultime : +8 % à toutes les statistiques.", dict(), dict(mesh="crown_big", color="#fff2c0", metal=1.0, emit="#3ff0e0"), ["campaign"], [dict(type="all_stats", pct=8)])
item("h_horned_helm_cos", "Heaume cornu de parade", H, "helmet", "epic", "Cosmétique : apparence seulement.", {}, dict(mesh="helm_horned", color="#3a3a42", metal=1.0, emit="#ff4040"), ["pass"], cosmetic=True)

# Eyes
E = "eyes"
item("e_monocle", "Monocle de mécanicien", E, "lens", "common", "Améliore la précision.", dict(range=0.2), dict(mesh="monocle", color="#c0a060", metal=1.0), ["chest"])
item("e_red_lenses", "Lentilles rouges", E, "lens", "rare", "Vision de combat.", dict(dmg=6), dict(mesh="goggles", color="#a01818", emit="#ff3030"), ["chest", "shop"])
item("e_oeil_pillard", "Œil du Pillard", E, "relic_eye", "epic", "Relique : révèle pièges et unités furtives (rayon 5), +10 % contre les structures.", dict(), dict(mesh="eye_glow", color="#ffd23f", emit="#ffd23f"), ["chest", "event"], [dict(type="reveal", radius=5.0), dict(type="bonus_vs_structures", mult=1.1)])
item("e_void_eyes", "Yeux du néant", E, "mutation_eye", "legendary", "Yeux mutés luminescents.", dict(range=0.4, ability_power_pct=8), dict(mesh="eye_glow", color="#8a5cff", emit="#b28cff"), ["chest"])

# Torso
T = "torso"
item("t_rags", "Haillons de guerre", T, "cloth", "common", "Tenue de départ.", dict(hp=40), dict(mesh="tunic", color="#5a4630"), ["starter"])
item("t_leather", "Armure de cuir", T, "leather", "common", "Cuir tanné de sanglier.", dict(hp=120, armor=4), dict(mesh="vest", color="#6b4a2b"), ["chest", "shop"])
item("t_scrap", "Plastron de ferraille", T, "plate", "rare", "Assemblé avec des débris.", dict(hp=180, armor=10, speed_pct=-4), dict(mesh="plate", color="#7b7f86", metal=0.8), ["chest", "craft"])
item("t_plate", "Plastron d'acier", T, "plate", "epic", "Acier gobelin forgé.", dict(hp=320, armor=16, speed_pct=-5), dict(mesh="plate", color="#9aa0a8", metal=1.0), ["craft", "shop"])
item("t_carapace", "Carapace mutante", T, "carapace", "epic", "Carapace organique vivante : régénère légèrement.", dict(hp=280, armor=12), dict(mesh="carapace", color="#5a1e5e", emit="#d03fd9"), ["craft", "chest"], [dict(type="regen", pct=1.0)])
item("t_mech_frame", "Châssis mécanique", T, "mech", "epic", "Exosquelette : compte comme module mécanique (Surcharge).", dict(hp=220, armor=10, atk_speed_pct=6), dict(mesh="mech_frame", color="#8d8f94", metal=1.0, emit="#ff8a2b"), ["craft"], [dict(type="mech_module")])
item("t_mystic_robe", "Robe arcanique", T, "cloth", "rare", "Tissée de fils runiques.", dict(hp=100, ability_power_pct=12, cdr_pct=5), dict(mesh="robe", color="#2f3a60", emit="#58a6ff"), ["chest", "pass"])
item("t_royal_armor", "Armure royale", T, "plate", "legendary", "L'armure des rois de Varkon.", dict(hp=450, armor=20), dict(mesh="plate_royal", color="#e0b84a", metal=1.0), ["craft", "shop"])
item("t_ancestral", "Cuirasse ancestrale", T, "plate", "mythic", "Gravée de runes oubliées.", dict(hp=520, armor=22, resist=15), dict(mesh="plate_royal", color="#d8f6ff", metal=1.0, emit="#3ff0e0"), ["chest", "event"])

# Shoulders
S = "shoulders"
item("s_pads", "Épaulières de cuir", S, "pads", "common", "Simples protections.", dict(armor=3), dict(mesh="pads", color="#6b4a2b"), ["chest"])
item("s_spikes", "Épaulières à pointes", S, "pads", "rare", "Hérissées de clous.", dict(armor=6, dmg=4), dict(mesh="pads_spiked", color="#6d7076", metal=0.9), ["chest", "shop"])
item("s_trophy", "Trophées de crânes", S, "trophy", "epic", "Les crânes de rivaux vaincus.", dict(hp=150, dmg=6), dict(mesh="skulls", color="#e8dcc0"), ["chest", "achievement"])
item("s_royal", "Épaulières royales", S, "plate", "legendary", "Plaques dorées.", dict(armor=14, hp=160), dict(mesh="pads_big", color="#e0b84a", metal=1.0), ["craft", "pass"])

# Hands
HA = "hands"
item("ha_wraps", "Bandages", HA, "gloves", "common", "Pour mieux tenir l'arme.", dict(atk_speed_pct=3), dict(mesh="wraps", color="#c8b896"), ["starter", "chest"])
item("ha_iron_gloves", "Gantelets de fer", HA, "gloves", "rare", "Lourds mais solides.", dict(armor=5, dmg=5), dict(mesh="gauntlet", color="#7b7f86", metal=0.9), ["chest", "shop"])
item("ha_gantelet_broyeur", "Gantelet du Broyeur", HA, "relic_glove", "epic", "Relique : une attaque sur quatre devient une frappe lourde (x2, étourdit 0,5 s).", dict(dmg=8), dict(mesh="gauntlet_big", color="#8d8f94", metal=1.0, emit="#ff8a2b"), ["craft", "chest"], [dict(type="heavy_every", n=4, mult=2.0, stun=0.5)])
item("ha_rings", "Bagues de pillard", HA, "rings", "rare", "Volées à un marchand.", dict(ability_power_pct=8), dict(mesh="rings", color="#ffd23f", metal=1.0), ["chest"])

# Legs / feet
LE = "legs"
item("le_trousers", "Braies usées", LE, "cloth", "common", "Confortables.", dict(speed_pct=2), dict(mesh="trousers", color="#4a3a28"), ["starter"])
item("le_greaves", "Jambières de fer", LE, "plate", "rare", "Protègent les tibias.", dict(armor=6, hp=80), dict(mesh="greaves", color="#7b7f86", metal=0.9), ["chest", "shop"])
item("le_runner", "Jambières de coureur", LE, "leather", "epic", "Légères et souples.", dict(speed_pct=10), dict(mesh="trousers", color="#2b4a3a"), ["craft", "pass"])
F = "feet"
item("f_sandals", "Sandales", F, "boots", "common", "Mieux que rien.", dict(speed_pct=2), dict(mesh="boots", color="#6b4a2b"), ["starter"])
item("f_iron_boots", "Bottes ferrées", F, "boots", "rare", "Écrasent tout.", dict(armor=4, hp=60), dict(mesh="boots_big", color="#7b7f86", metal=0.9), ["chest", "shop"])
item("f_hooves", "Sabots mutants", F, "mutation", "epic", "Sabots organiques puissants.", dict(speed_pct=8, hp=80), dict(mesh="hooves", color="#3a2a20"), ["craft", "chest"])

# Back
B = "back"
item("b_sack", "Sac de pillard", B, "bag", "common", "Pour le butin.", dict(hp=40), dict(mesh="sack", color="#8a6a40"), ["chest"])
item("b_quiver", "Carquois", B, "quiver", "rare", "Améliore les armes à distance.", dict(range=0.5), dict(mesh="quiver", color="#6b4a2b"), ["chest", "shop"])
item("b_moteur_gobelin", "Moteur gobelin", B, "mech", "epic", "Relique : +15 % PV aux unités mécaniques, Surcharge -20 % de recharge. Compte comme module mécanique.", dict(atk_speed_pct=5), dict(mesh="engine", color="#8d8f94", metal=1.0, emit="#ff8a2b"), ["craft"], [dict(type="family_hp", family="mech", pct=15), dict(type="cdr_ability", ability="overcharge", pct=20), dict(type="mech_module")])
item("b_wings", "Ailes de chauve-souris", B, "wings", "legendary", "Ailes mutantes : +vitesse.", dict(speed_pct=12), dict(mesh="wings", color="#2a1a2a", emit="#8a5cff"), ["chest", "pass"])
item("b_jetpack", "Réacteur gobelin", B, "mech", "legendary", "Réacteur bricolé : +vitesse, module mécanique.", dict(speed_pct=10, atk_speed_pct=5), dict(mesh="jetpack", color="#7a7f88", metal=1.0, emit="#ffb347"), ["craft"], [dict(type="mech_module")])
item("b_tentacles", "Tentacules dorsaux", B, "mutation", "mythic", "Tentacules qui immobilisent : un coup sur six enracine 1 s.", dict(hp=200), dict(mesh="tentacles", color="#5a1e5e", emit="#d03fd9"), ["chest", "event"], [dict(type="hero_root_every", n=6, dur=1.0)])
item("b_banner", "Bannière de clan", B, "banner", "rare", "Cosmétique : affiche vos couleurs.", {}, dict(mesh="banner", color="#c9472b"), ["pass", "shop"], cosmetic=True)

# Belt
BE = "belt"
item("be_rope", "Ceinture de corde", BE, "belt", "common", "Tient les braies.", dict(hp=30), dict(mesh="belt", color="#8a6a40"), ["starter"])
item("be_flasks", "Ceinture à fioles", BE, "belt", "rare", "Fioles de soin : régénération.", dict(hp=60), dict(mesh="belt_flasks", color="#6b4a2b", emit="#7bdc3a"), ["chest", "craft"], [dict(type="regen", pct=0.8)])
item("be_totem_hurleur", "Totem du Hurleur", BE, "relic_belt", "epic", "Relique : alliés à moins de 4 m +10 % dégâts.", dict(), dict(mesh="totem", color="#b5652b"), ["chest", "event"], [dict(type="ally_aura", stat="damage", pct=10, radius=4.0)])
item("be_tools", "Ceinture d'outils", BE, "belt", "rare", "Outils de mécanicien : -8 % recharge.", dict(cdr_pct=8), dict(mesh="belt_tools", color="#5a4630", metal=0.5), ["craft"])

# Auras (cosmetic or light)
A = "aura"
item("a_embers", "Aura de braises", A, "aura", "rare", "Cosmétique : particules de braise.", {}, dict(mesh="aura", color="#ff6a1f"), ["chest", "pass"], cosmetic=True)
item("a_frost", "Aura de givre", A, "aura", "rare", "Cosmétique : flocons tourbillonnants.", {}, dict(mesh="aura", color="#7fd8ff"), ["chest", "shop"], cosmetic=True)
item("a_toxic", "Aura toxique", A, "aura", "epic", "Cosmétique : fumée verte.", {}, dict(mesh="aura", color="#7bdc3a"), ["pass", "shop"], cosmetic=True)
item("a_storm", "Aura électrique", A, "aura", "legendary", "Cosmétique : arcs électriques.", {}, dict(mesh="aura", color="#9ad7ff"), ["shop", "pass"], cosmetic=True)
item("a_void", "Aura du néant", A, "aura", "mythic", "Cosmétique : énergie sombre.", {}, dict(mesh="aura", color="#8a5cff"), ["event", "chest"], cosmetic=True)
item("a_ancestral", "Aura ancestrale", A, "aura", "ancestral", "Cosmétique : lumière des anciens rois.", {}, dict(mesh="aura", color="#3ff0e0"), ["achievement"], cosmetic=True)

# Special slot relics
SP = "special"
item("r_coeur_fourneau", "Cœur du Fourneau", SP, "relic", "epic", "Relique : unités de feu +15 % dégâts, mais résistance du King -10.", dict(resist=-10), dict(mesh="relic_heart", color="#ff6a1f", emit="#ff6a1f"), ["chest", "craft"], [dict(type="family_dmg", family="fire", pct=15)])
item("r_noyau_instable", "Noyau instable", SP, "relic", "legendary", "Relique : sous 30 % de vie, le King explose (400 dégâts, rayon 3), une fois par vie.", dict(), dict(mesh="relic_core", color="#ff3d6e", emit="#ff3d6e"), ["craft", "chest"], [dict(type="last_stand_explosion", threshold=0.3, dmg=400, radius=3.0)])
item("r_sceau_glace", "Sceau de givre", SP, "relic", "rare", "Relique : unités de glace +15 % PV.", dict(), dict(mesh="relic_core", color="#7fd8ff", emit="#7fd8ff"), ["chest"], [dict(type="family_hp", family="ice", pct=15)])
item("r_idole_toxique", "Idole toxique", SP, "relic", "rare", "Relique : unités toxiques +15 % dégâts.", dict(), dict(mesh="relic_core", color="#7bdc3a", emit="#7bdc3a"), ["chest"], [dict(type="family_dmg", family="toxic", pct=15)])
item("r_etendard_royal", "Étendard de la couronne", SP, "relic", "epic", "Relique : unités royales +15 % PV et dégâts.", dict(), dict(mesh="relic_heart", color="#ffd23f", emit="#ffd23f"), ["craft"], [dict(type="family_hp", family="royal", pct=15), dict(type="family_dmg", family="royal", pct=15)])

# Emotes / victory animations / entries (cosmetic collection, stored in inventory)
COSMETICS = [
    dict(id="emote_laugh", name="Rire royal", kind="emote", rarity="common", anim="laugh", sources=["starter"]),
    dict(id="emote_smash", name="Frappe au sol", kind="emote", rarity="common", anim="smash", sources=["starter"]),
    dict(id="emote_cross", name="Bras croisés", kind="emote", rarity="rare", anim="cross_arms", sources=["pass", "shop"]),
    dict(id="emote_spin", name="Moulinet", kind="emote", rarity="rare", anim="spin_weapon", sources=["chest", "pass"]),
    dict(id="emote_roar", name="Rugissement", kind="emote", rarity="epic", anim="roar", sources=["pass", "shop"]),
    dict(id="victory_jump", name="Saut de victoire", kind="victory", rarity="common", anim="jump", sources=["starter"]),
    dict(id="victory_flex", name="Démonstration de force", kind="victory", rarity="epic", anim="flex", sources=["pass", "shop"]),
    dict(id="victory_throne", name="Assis sur le trône", kind="victory", rarity="legendary", anim="throne", sources=["pass"]),
    dict(id="entry_smoke", name="Entrée fumigène", kind="entry", rarity="rare", anim="smoke", sources=["pass", "shop"]),
    dict(id="entry_lightning", name="Entrée foudroyante", kind="entry", rarity="legendary", anim="lightning", sources=["shop", "event"]),
    dict(id="defeat_shrug", name="Haussement d'épaules", kind="defeat", rarity="rare", anim="shrug", sources=["pass"]),
    dict(id="taunt_tongue", name="Provocation", kind="emote", rarity="rare", anim="taunt", sources=["chest", "shop"]),
]

# --------------------------------------------------------------------------- KING
KING = dict(
    base=dict(hp=2200, dmg=120, armor=20, speed=1.8, atk_speed=1.0, range=1.0, energy=0, resist=0, cdr_pct=0, ability_power_pct=0),
    per_level=dict(hp=0.05, dmg=0.05),  # +5 % per player level
    caps=dict(armor=80, speed_pct=35, atk_speed_pct=50, cdr_pct=40, range=5.0, resist=60, ability_power_pct=80, energy=2),
    weapon_styles=dict(
        sword=dict(hit=1.0, range=1.0, proj=0), axe=dict(hit=1.25, range=1.0, proj=0), hammer=dict(hit=1.5, range=1.1, proj=0, splash=1.0),
        dagger=dict(hit=0.65, range=0.9, proj=0), spear=dict(hit=1.1, range=1.6, proj=0), magic=dict(hit=1.2, range=1.0, proj=10),
        mech=dict(hit=1.1, range=1.0, proj=0), claws=dict(hit=0.75, range=0.9, proj=0), ranged=dict(hit=1.1, range=1.0, proj=12),
        none=dict(hit=1.0, range=1.0, proj=0)),
    abilities=[
        dict(id="tyrant_strike", slot="active", name="Frappe du Tyran", desc="Frappe le sol : 250 % de dégâts dans un rayon de 2,5 et repousse les ennemis.", cooldown=10, power=2.5, radius=2.5, force=2.0, unlock=None),
        dict(id="axe_throw", slot="active", name="Hache volante", desc="Lance une hache sur l'ennemi le plus proche (portée 6) : 200 % de dégâts.", cooldown=8, power=2.0, range=6.0, unlock=("player_level", 3)),
        dict(id="overcharge", slot="active", name="Surcharge", desc="Améliore les modules mécaniques : King et unités mécaniques +40 % de cadence pendant 6 s. Nécessite un module mécanique.", cooldown=18, pct=40, dur=6, radius=6.0, unlock=("player_level", 5), requires="mech_module"),
        dict(id="iron_skin", slot="defensive", name="Peau de fer", desc="Bouclier égal à 30 % des PV max pendant 5 s.", cooldown=16, pct=30, dur=5, unlock=None),
        dict(id="royal_roar", slot="defensive", name="Rugissement royal", desc="Gobelins alliés (rayon 6) : +25 % dégâts et +20 armure pendant 6 s.", cooldown=20, pct=25, armor=20, dur=6, radius=6.0, unlock=("campaign", "c1m3")),
        dict(id="mutant_fury", slot="ultimate", name="Fureur mutante", desc="Transformation 10 s : +60 % dégâts, +20 % vitesse, vol de vie 20 %, taille accrue.", charge=100, dur=10, dmg_pct=60, speed_pct=20, lifesteal=20, unlock=None),
        dict(id="raider_call", slot="ultimate", name="Appel des Pillards", desc="Invoque une escouade temporaire : 4 pillards et un chef pillard.", charge=100, unlock=("campaign", "c2m2")),
        dict(id="royal_presence", slot="passive", name="Présence royale", desc="Alliés à moins de 4 m : +15 armure.", armor=15, radius=4.0, unlock=None),
        dict(id="tyrant_blood", slot="passive", name="Sang de tyran", desc="Vol de vie de 8 % sur les attaques du King.", pct=8, unlock=("player_level", 4)),
        dict(id="mech_instinct", slot="passive", name="Instinct mécanique", desc="+15 % de cadence si l'arme est mécanique.", pct=15, unlock=("player_level", 6)),
    ],
    appearance=dict(
        face_shape=["Rond", "Anguleux", "Allongé", "Carré"],
        ears=["Pointues", "Tombantes", "Longues", "Déchirées", "Ailées"],
        nose=["Crochu", "Écrasé", "Long", "Bulbeux"],
        jaw=["Étroite", "Large", "Proéminente", "Massive"],
        teeth=["Alignées", "Pointues", "Cassées", "Dents d'or"],
        tusks=["Aucune", "Petites", "Grandes", "Recourbées"],
        eyes=["Ronds", "Plissés", "Grands", "Fendus"],
        eye_color=["#ffd23f", "#ff3030", "#7fd8ff", "#7bdc3a", "#b28cff", "#ffffff"],
        skin=["#7ea83e", "#6a9638", "#94b84a", "#8aa23e", "#5aa08a", "#b0a64a", "#8a8fc0", "#c27a4a"],
        scars=["Aucune", "Joue", "Œil", "Croisées", "Multiples"],
        paint=["Aucune", "Rayures", "Crâne", "Éclair", "Points tribaux", "Mille Visages I", "Mille Visages II", "Mille Visages III"],
        paint_color=["#c9472b", "#ffffff", "#1a1a1a", "#3d8bff", "#ffd23f"],
        horns=["Aucune", "Petites", "Bélier", "Démon"],
        crest=["Aucune", "Iroquoise", "Piquants", "Plumes"],
        hair=["Chauve", "Mèches", "Tresse", "Crinière"],
        hair_color=["#1a1410", "#5a3a20", "#c9472b", "#e8e8e8", "#ffd23f"],
        height=[0.9, 0.95, 1.0, 1.05, 1.1],
        bulk=[0.85, 0.95, 1.0, 1.1, 1.2],
        muscle=["Sec", "Athlétique", "Massif", "Colossal"],
        expression=["Neutre", "Rictus", "Furieux", "Hilare"],
        voice=["Grave", "Rocailleuse", "Aiguë", "Royale"],
    ),
    # Advanced options unlock progressively (option index >= threshold requires level)
    appearance_locks=dict(horns=dict(index=2, player_level=5), crest=dict(index=2, player_level=4), ears=dict(index=4, player_level=6), skin=dict(index=6, player_level=7)),
    # Paint variants unlocked by items with an "unlock_paints" effect (Masque des Mille Visages)
    item_paints={"5": "mille_1", "6": "mille_2", "7": "mille_3"},
)

MUTATIONS = [
    dict(id="m_arms", name="Bras renforcés", desc="+8 % dégâts. Les bras du King grossissent.", cost=dict(mutant_essence=80), stats=dict(dmg_pct=8), visual="big_arms"),
    dict(id="m_scales", name="Peau écailleuse", desc="+10 armure. Écailles sur le corps.", cost=dict(mutant_essence=80), stats=dict(armor=10), visual="scales"),
    dict(id="m_eyes", name="Yeux de prédateur", desc="+0,5 portée. Yeux luminescents.", cost=dict(mutant_essence=100), stats=dict(range=0.5), visual="glow_eyes"),
    dict(id="m_spines", name="Épines dorsales", desc="Renvoie 10 % des dégâts de mêlée. Épines dans le dos.", cost=dict(mutant_essence=140), stats={}, effects=[dict(type="thorns", pct=10)], visual="spines"),
    dict(id="m_fangs", name="Crocs géants", desc="Vol de vie 5 %. Défenses immenses.", cost=dict(mutant_essence=140), stats={}, effects=[dict(type="hero_lifesteal", pct=5)], visual="big_tusks"),
    dict(id="m_regen", name="Sang troll", desc="Régénère 1 % des PV max par seconde.", cost=dict(mutant_essence=200), stats={}, effects=[dict(type="regen", pct=1.0)], visual="veins"),
    dict(id="m_ancestral", name="Éveil ancestral", desc="+5 % à toutes les statistiques, aura spectrale. Nécessite une Larme ancestrale.", cost=dict(mutant_essence=300, mat_larme_ancestrale=1), stats={}, effects=[dict(type="all_stats", pct=5)], visual="ancestral_glow"),
]

# --------------------------------------------------------------------------- BUILDINGS
BUILDINGS = [
    dict(id="fortress", name="Forteresse", size=[4, 4], max_level=10, zone="center", desc="Centre du royaume. Son niveau limite celui des autres bâtiments et débloque des zones.",
         base_cost=dict(gold=400), cost_growth=2.1, base_time=40, unique=True, color="#6d5a4a"),
    dict(id="barracks", effect=dict(card_stat_pct=3), name="Caserne", size=[3, 3], max_level=10, zone="center", desc="Améliore les troupes : +3 % PV et dégâts des cartes en combat par niveau.",
         base_cost=dict(gold=200), cost_growth=1.9, base_time=25, unique=True, color="#7a3a2a", req=dict(fortress=1)),
    dict(id="treasury", effect=dict(mine_cap_per_level=300), name="Trésorerie", size=[2, 2], max_level=10, zone="center", desc="Stocke l'or produit par les mines (capacité +300 par niveau).",
         base_cost=dict(gold=150), cost_growth=1.8, base_time=20, unique=True, color="#d9b44a", req=dict(fortress=1)),
    dict(id="gold_mine", production=dict(resource="gold", per_hour=40, cap_base=300), name="Mine gobeline", size=[2, 2], max_level=10, zone="center", desc="Produit de l'or en continu (40/h par niveau), dans la limite de la Trésorerie.",
         base_cost=dict(gold=120), cost_growth=1.8, base_time=15, unique=False, max_count=3, color="#a07a3a", req=dict(fortress=1)),
    dict(id="crystal_works", production=dict(resource="crystals", per_hour=1, cap_per_level=6), name="Cristallerie", size=[2, 2], max_level=8, zone="industrial", desc="Produit lentement des cristaux (1/h par niveau, stock max 6 par niveau).",
         base_cost=dict(gold=600), cost_growth=2.0, base_time=60, unique=True, color="#58a6ff", req=dict(fortress=2)),
    dict(id="workshop", production=dict(resource="components", per_hour=8, cap_per_level=60), name="Atelier", size=[3, 2], max_level=10, zone="industrial", desc="Produit des composants mécaniques (8/h par niveau) et débloque des recettes.",
         base_cost=dict(gold=300), cost_growth=1.9, base_time=30, unique=True, color="#8d8f94", req=dict(fortress=2)),
    dict(id="card_hall", name="Salle des cartes", size=[3, 3], max_level=10, zone="center", desc="Niveau maximum des cartes = niveau de la salle + 2.",
         base_cost=dict(gold=250), cost_growth=1.9, base_time=25, unique=True, color="#4a3a6a", req=dict(fortress=1)),
    dict(id="laboratory", name="Laboratoire", size=[3, 3], max_level=8, zone="center", desc="Conception, mutation, recherche, recyclage et reliques du King Gobelin.",
         base_cost=dict(gold=1500, components=100), cost_growth=2.0, base_time=60, unique=True, color="#3a6a5a", req=dict(fortress=4), locked_ruin=True),
    dict(id="royal_forge", name="Forge royale", size=[3, 2], max_level=8, zone="industrial", desc="Fabrique armes et armures. Son niveau débloque les recettes de rareté supérieure.",
         base_cost=dict(gold=500, components=30), cost_growth=2.0, base_time=45, unique=True, color="#8a3a1a", req=dict(fortress=3)),
    dict(id="watchtower", effect=dict(tower_pct=8), name="Tour de garde", size=[1, 1], max_level=10, zone="center", desc="Défense : +8 % PV et dégâts des tours en combat par niveau (tour la plus haute).",
         base_cost=dict(gold=180), cost_growth=1.85, base_time=20, unique=False, max_count=4, color="#7a6a55", req=dict(fortress=1)),
    dict(id="wall", effect=dict(wall_hp=900, wall_hp_pct=15), name="Muraille", size=[1, 1], max_level=10, zone="center", desc="Ajoute des segments de muraille en mode Défense (1 segment pour 2 murailles) ; PV selon le niveau.",
         base_cost=dict(gold=60), cost_growth=1.7, base_time=5, unique=False, max_count=12, color="#6a6a6a", req=dict(fortress=1)),
    dict(id="trap", effect=dict(trap_dmg=220, trap_dmg_pct=15), name="Piège gobelin", size=[1, 1], max_level=8, zone="center", desc="Ajoute un piège à pointes en mode Défense et Survie (dégâts selon le niveau).",
         base_cost=dict(gold=150), cost_growth=1.8, base_time=10, unique=False, max_count=4, color="#5a3a20", req=dict(fortress=2)),
    dict(id="raid_portal", effect=dict(raid_reward_pct=10), name="Portail de raid", size=[2, 2], max_level=6, zone="center", desc="Donne accès aux raids. Le niveau augmente les récompenses de raid (+10 %/niv.).",
         base_cost=dict(gold=350), cost_growth=2.0, base_time=30, unique=True, color="#6a2a8a", req=dict(fortress=2)),
    dict(id="trophy_hall", effect=dict(battle_gold_pct=2), name="Hall des trophées", size=[3, 2], max_level=6, zone="royal", desc="Expose vos succès : +2 % d'or gagné en combat par niveau.",
         base_cost=dict(gold=1200, crystals=20), cost_growth=2.0, base_time=60, unique=True, color="#ffd23f", req=dict(fortress=6)),
    dict(id="mutant_pen", production=dict(resource="mutant_essence", per_hour=4, cap_per_level=40), name="Enclos mutant", size=[3, 3], max_level=8, zone="mutant_garden", desc="Étudie des créatures : produit de l'essence mutante (4/h par niveau).",
         base_cost=dict(gold=800, components=40), cost_growth=2.0, base_time=45, unique=True, color="#d03fd9", req=dict(fortress=3)),
    dict(id="research_hall", name="Salle de recherche", size=[3, 2], max_level=8, zone="mechanical", desc="Débloque les technologies (niveau max de recherche = niveau de la salle).",
         base_cost=dict(gold=1000, components=60), cost_growth=2.0, base_time=60, unique=True, color="#4aa3ff", req=dict(fortress=5)),
]

ZONES = [
    dict(id="center", name="Centre de la forteresse", rect=[8, 8, 10, 10], cost={}, req=dict(fortress=1), desc="Cœur de votre royaume."),
    dict(id="industrial", name="Quartier industriel", rect=[18, 8, 6, 10], cost=dict(gold=500), req=dict(fortress=2), desc="Atelier, forge et cristallerie."),
    dict(id="mutant_garden", name="Jardin mutant", rect=[8, 2, 10, 6], cost=dict(gold=1200), req=dict(fortress=3), desc="Végétation mutante et enclos."),
    dict(id="creature_pen", name="Enclos des créatures", rect=[2, 8, 6, 10], cost=dict(gold=2000), req=dict(fortress=4), desc="+6 emplacements de construction et +1 mine possible.", bonus=dict(gold_mine_max=1)),
    dict(id="mechanical", name="District mécanique", rect=[18, 18, 6, 6], cost=dict(gold=3500, components=100), req=dict(fortress=5), desc="Salle de recherche et machines."),
    dict(id="royal", name="Zone royale", rect=[8, 18, 10, 6], cost=dict(gold=6000, crystals=50), req=dict(fortress=6), desc="Hall des trophées et monuments."),
    dict(id="advanced_lab", name="Laboratoire avancé", rect=[2, 18, 6, 6], cost=dict(gold=9000, components=300, mutant_essence=150), req=dict(fortress=7, building="laboratory"), desc="+1 emplacement de mutation et +1 configuration.", bonus=dict(mutation_slots=1, loadout_slots=1)),
]

GRID = dict(width=26, height=26)

# Initial layout of a new profile
START_BASE = [
    dict(id="fortress", x=11, y=12, level=1), dict(id="barracks", x=8, y=8, level=1), dict(id="treasury", x=15, y=8, level=1),
    dict(id="gold_mine", x=8, y=15, level=1), dict(id="card_hall", x=15, y=15, level=1), dict(id="watchtower", x=16, y=11, level=1),
    dict(id="laboratory", x=12, y=8, level=0), dict(id="wall", x=8, y=12, level=1), dict(id="wall", x=9, y=12, level=1),
]

# --------------------------------------------------------------------------- LAB
LAB = dict(
    unlock=[dict(type="building_level", building="fortress", level=4, text="Forteresse de niveau 4"),
            dict(type="campaign", mission="c2m8", text="Chapitre 2 terminé"),
            dict(type="flag", flag="lab_repaired", text="Mission de réparation accomplie")],
    repair_cost=dict(gold=800, components=60),
    rooms=[
        dict(id="design", name="Salle de conception", desc="Équiper, modifier et fabriquer des modules.", lab_level=1),
        dict(id="mutation", name="Salle de mutation", desc="Débloquer des transformations physiques.", lab_level=1),
        dict(id="experiment", name="Salle d'expérimentation", desc="Tester une configuration contre des mannequins ou des bots.", lab_level=1),
        dict(id="research", name="Salle de recherche", desc="Améliorer des technologies.", lab_level=2),
        dict(id="recycle", name="Salle de recyclage", desc="Transformer des objets en matériaux.", lab_level=2),
        dict(id="relics", name="Salle des reliques", desc="Étudier et améliorer les reliques.", lab_level=3),
    ],
    recycle=dict(common=dict(components=8), rare=dict(components=25), epic=dict(components=60, mutant_essence=10),
                 legendary=dict(components=140, ancestral=2), mythic=dict(components=300, ancestral=6), ancestral=dict(components=600, ancestral=15)),
    relic_upgrade=dict(max_level=5, cost_per_level=dict(ancestral=4, gold=1000), bonus_pct_per_level=10),
    mutation_slots=2,
)

RESEARCH = [
    dict(id="economy", name="Économie gobeline", desc="+5 % d'or gagné en combat par niveau.", max=3, cost=dict(gold=800, components=40), time=120, per_level=dict(battle_gold_pct=5)),
    dict(id="engineering", name="Ingénierie", desc="-15 % de temps de fabrication par niveau.", max=3, cost=dict(gold=700, components=60), time=120, per_level=dict(craft_time_pct=-15)),
    dict(id="tactics", name="Tactique", desc="+0,5 rage au début des combats par niveau.", max=2, cost=dict(gold=1500, components=80), time=300, per_level=dict(start_energy=0.5)),
    dict(id="fortification", name="Fortification", desc="+5 % PV des structures en combat par niveau.", max=3, cost=dict(gold=900, components=50), time=180, per_level=dict(structure_hp_pct=5)),
    dict(id="genetics", name="Génétique", desc="+1 emplacement de mutation.", max=1, cost=dict(gold=3000, mutant_essence=200), time=600, per_level=dict(mutation_slots=1)),
    dict(id="logistics", name="Logistique", desc="+1 emplacement de configuration du King.", max=1, cost=dict(gold=2500, components=150), time=600, per_level=dict(loadout_slots=1)),
    dict(id="advanced_forge", name="Forge avancée", desc="Débloque les recettes légendaires.", max=1, cost=dict(gold=4000, components=200, ancestral=5), time=900, per_level=dict(unlock_legendary_recipes=1)),
]

RECIPES = []


def recipe(item_id, station, cost, time, req=None):
    RECIPES.append(dict(id="rc_" + item_id, item=item_id, station=station, cost=cost, time=time, requires=req or {}))


recipe("w_brise_fer", "forge", dict(gold=600, components=40), 60, dict(royal_forge=1))
recipe("w_crocs_noirs", "forge", dict(gold=600, components=40), 60, dict(royal_forge=1))
recipe("w_arbalete", "workshop", dict(gold=500, components=50), 60, dict(workshop=2))
recipe("w_fendoir_royal", "forge", dict(gold=1500, components=90), 180, dict(royal_forge=3))
recipe("w_epine_arcanique", "lab", dict(gold=1500, components=60, mutant_essence=40), 180, dict(laboratory=1))
recipe("w_machoire_acier", "lab", dict(gold=1600, components=120), 180, dict(laboratory=1))
recipe("w_canon_main", "lab", dict(gold=4000, components=250, ancestral=4), 600, dict(laboratory=3, research="advanced_forge"))
recipe("w_marteau_roi", "forge", dict(gold=4500, components=200, ancestral=5), 600, dict(royal_forge=5, research="advanced_forge"))
recipe("l_iron_shield", "forge", dict(gold=500, components=40), 60, dict(royal_forge=1))
recipe("l_rune_shield", "lab", dict(gold=1400, components=70, mutant_essence=20), 180, dict(laboratory=1))
recipe("l_royal_shield", "forge", dict(gold=4000, components=180, ancestral=4), 600, dict(royal_forge=5, research="advanced_forge"))
recipe("h_bone_crown", "forge", dict(gold=500, components=30), 60, dict(royal_forge=1))
recipe("h_gear_helm", "lab", dict(gold=1500, components=100), 180, dict(laboratory=1))
recipe("t_scrap", "workshop", dict(gold=400, components=50), 60, dict(workshop=1))
recipe("t_plate", "forge", dict(gold=1500, components=100), 180, dict(royal_forge=3))
recipe("t_carapace", "lab", dict(gold=1500, components=40, mutant_essence=80), 180, dict(laboratory=2))
recipe("t_mech_frame", "lab", dict(gold=1800, components=140), 240, dict(laboratory=1))
recipe("t_royal_armor", "forge", dict(gold=5000, components=220, ancestral=6), 600, dict(royal_forge=6, research="advanced_forge"))
recipe("s_royal", "forge", dict(gold=3500, components=150, ancestral=3), 480, dict(royal_forge=5, research="advanced_forge"))
recipe("ha_gantelet_broyeur", "lab", dict(gold=1600, components=110), 180, dict(laboratory=1))
recipe("le_runner", "workshop", dict(gold=1200, components=70), 120, dict(workshop=3))
recipe("f_hooves", "lab", dict(gold=1200, mutant_essence=70), 120, dict(laboratory=2))
recipe("b_moteur_gobelin", "lab", dict(gold=2000, components=160), 300, dict(laboratory=2))
recipe("b_jetpack", "lab", dict(gold=4200, components=260, ancestral=4), 600, dict(laboratory=4, research="advanced_forge"))
recipe("be_flasks", "workshop", dict(gold=600, components=30, mutant_essence=10), 60, dict(workshop=2))
recipe("be_tools", "workshop", dict(gold=700, components=60), 90, dict(workshop=2))
recipe("r_coeur_fourneau", "lab", dict(gold=1800, components=60, mutant_essence=60), 240, dict(laboratory=2))
recipe("r_noyau_instable", "lab", dict(gold=4500, components=200, mutant_essence=120, ancestral=4), 600, dict(laboratory=4, research="advanced_forge"))
recipe("r_etendard_royal", "lab", dict(gold=2200, components=100), 240, dict(laboratory=3))

MATERIALS = [
    dict(id="mat_larme_ancestrale", name="Larme ancestrale", rarity="mythic", desc="Matériau rare permettant la mutation Éveil ancestral.", sources=["chest", "boss", "achievement"]),
]

# --------------------------------------------------------------------------- RESOURCES
RESOURCES = [
    dict(id="gold", name="Or", color="#ffd23f", desc="Améliorations, bâtiments et achats courants."),
    dict(id="crystals", name="Cristaux", color="#58a6ff", desc="Monnaie premium, aussi gagnée gratuitement (missions, pass, succès, Cristallerie)."),
    dict(id="fragments", name="Fragments", color="#e0a0ff", desc="Remplacent des copies manquantes pour améliorer les cartes."),
    dict(id="components", name="Composants", color="#b7a27a", desc="Fabrication des modules et équipements mécaniques."),
    dict(id="mutant_essence", name="Essence mutante", color="#d03fd9", desc="Mutations et transformations."),
    dict(id="war_tokens", name="Jetons de guerre", color="#c9472b", desc="Défis, événements et boutique d'événement."),
    dict(id="ancestral", name="Matériaux ancestraux", color="#3ff0e0", desc="Fabrication d'objets rares et reliques."),
]

CARD_UPGRADE = dict(
    max_level=10,
    copies=[0, 2, 4, 10, 20, 50, 100, 200, 400, 800],
    copies_div=dict(common=1, rare=2, epic=5, legendary=10, mythic=20, ancestral=40),
    gold=[0, 50, 150, 400, 1000, 2000, 4000, 8000, 15000, 30000],
    gold_mult=dict(common=1.0, rare=1.2, epic=1.5, legendary=2.0, mythic=2.5, ancestral=3.0),
    fragments_per_copy=dict(common=5, rare=20, epic=80, legendary=300, mythic=800, ancestral=2000),
    stat_per_level=0.10,
    rarity_start_level=dict(common=1, rare=1, epic=1, legendary=1, mythic=1, ancestral=1),
)

SYNERGIES = [
    dict(family="fire", need=3, name="Aura de chaleur", desc="3 cartes de feu dans le deck : unités de feu +12 % dégâts.", bonus=dict(damage_pct=12)),
    dict(family="ice", need=3, name="Hiver éternel", desc="3 cartes de glace : ralentissements +30 % de durée.", bonus=dict(slow_dur_pct=30)),
    dict(family="toxic", need=3, name="Miasmes", desc="3 cartes toxiques : poisons +25 % de dégâts.", bonus=dict(poison_pct=25)),
    dict(family="mech", need=3, name="Chaîne de montage", desc="3 cartes mécaniques : unités mécaniques +15 % PV.", bonus=dict(hp_pct=15)),
    dict(family="shadow", need=3, name="Voile nocturne", desc="3 cartes de l'ombre : unités de l'ombre +15 % dégâts.", bonus=dict(damage_pct=15)),
    dict(family="wild", need=3, name="Instinct de meute", desc="3 cartes sauvages : unités sauvages +10 % vitesse et +10 % PV.", bonus=dict(speed_pct=10, hp_pct=10)),
    dict(family="mystic", need=3, name="Convergence", desc="3 cartes mystiques : capacités +20 % de puissance.", bonus=dict(ability_power_pct=20)),
    dict(family="royal", need=3, name="Garde royale", desc="3 cartes royales : unités royales +15 armure, King +10 % PV.", bonus=dict(armor=15, king_hp_pct=10)),
    dict(family="mutant", need=3, name="Évolution", desc="3 cartes mutantes : unités mutantes régénèrent 1 % PV/s.", bonus=dict(regen_pct=1.0)),
    dict(family="air", need=2, name="Escadrille", desc="2 cartes aériennes : unités volantes +15 % dégâts.", bonus=dict(damage_pct=15)),
    dict(family="support", need=3, name="Logistique", desc="3 cartes de soutien : soins et boucliers +25 %.", bonus=dict(heal_pct=25)),
    dict(family="raider", need=3, name="Horde", desc="3 cartes de pillards : pillards +10 % vitesse d'attaque.", bonus=dict(atk_speed_pct=10)),
]

# --------------------------------------------------------------------------- CHESTS
CHESTS = [
    dict(id="chest_wood", name="Coffre de bois", rarity="common", color="#8a5a2b", desc="Or, cartes communes et composants simples.",
         gold=[80, 150], resources=dict(components=[5, 15]),
         rolls=[dict(type="card", count=3, weights=dict(common=85, rare=15))]),
    dict(id="chest_reinforced", name="Coffre renforcé", rarity="rare", color="#6d7076", desc="Ressources et cartes de rareté variable.",
         gold=[200, 400], resources=dict(fragments=[15, 30], components=[10, 25]),
         rolls=[dict(type="card", count=6, weights=dict(common=68, rare=26, epic=6))]),
    dict(id="chest_royal", name="Coffre royal", rarity="epic", color="#d9b44a", desc="Sélection de récompenses prestigieuses.",
         gold=[600, 1000], resources=dict(fragments=[40, 80], crystals=[5, 15]),
         rolls=[dict(type="card", count=12, weights=dict(common=50, rare=33, epic=13, legendary=3.5, mythic=0.5)),
                dict(type="item", count=1, weights=dict(rare=60, epic=32, legendary=7, mythic=1))]),
    dict(id="chest_goblin", name="Coffre de gobelins", rarity="rare", color="#5f8f3a", desc="Uniquement des cartes de gobelins.",
         gold=[50, 100], resources={},
         rolls=[dict(type="card", count=15, weights=dict(common=45, rare=35, epic=15, legendary=4, mythic=0.8, ancestral=0.2))]),
    dict(id="chest_module", name="Coffre de modules", rarity="epic", color="#8d8f94", desc="Équipements du King Gobelin.",
         gold=[100, 200], resources=dict(components=[30, 60]),
         rolls=[dict(type="item", count=2, weights=dict(common=40, rare=35, epic=18, legendary=6, mythic=1))]),
    dict(id="chest_mutation", name="Coffre de mutation", rarity="epic", color="#d03fd9", desc="Matériaux de transformation.",
         gold=[50, 100], resources=dict(mutant_essence=[40, 90]),
         rolls=[dict(type="material", id="mat_larme_ancestrale", chance=8), dict(type="resource", id="ancestral", amount=[1, 3], chance=40)]),
    dict(id="chest_ancestral", name="Coffre ancestral", rarity="ancestral", color="#3ff0e0", desc="Récompenses rares des défis et événements. Garantit un objet épique ou mieux.",
         gold=[1000, 2000], resources=dict(ancestral=[5, 10], crystals=[20, 40]),
         rolls=[dict(type="card", count=20, weights=dict(rare=55, epic=30, legendary=11, mythic=3, ancestral=1)),
                dict(type="item", count=1, weights=dict(epic=60, legendary=30, mythic=8, ancestral=2))]),
    dict(id="chest_victory", name="Coffre de victoire", rarity="common", color="#c9472b", desc="Récompense certains combats.",
         gold=[40, 80], resources={},
         rolls=[dict(type="card", count=2, weights=dict(common=80, rare=18, epic=2)), dict(type="resource", id="crystals", amount=[3, 6], chance=10)]),
]

# --------------------------------------------------------------------------- SHOP
SHOP = dict(
    daily_count=6,
    daily_pool=[
        dict(kind="card_copies", rarity="common", amount=20, price=dict(gold=200)),
        dict(kind="card_copies", rarity="rare", amount=10, price=dict(gold=600)),
        dict(kind="card_copies", rarity="epic", amount=4, price=dict(gold=2000)),
        dict(kind="card_copies", rarity="legendary", amount=1, price=dict(crystals=150)),
        dict(kind="resource", id="components", amount=60, price=dict(gold=500)),
        dict(kind="resource", id="mutant_essence", amount=40, price=dict(gold=700)),
        dict(kind="resource", id="fragments", amount=50, price=dict(gold=400)),
        dict(kind="chest", id="chest_reinforced", price=dict(gold=900)),
        dict(kind="item_random", rarity="rare", price=dict(gold=1500)),
        dict(kind="item_random", rarity="epic", price=dict(crystals=120)),
    ],
    sections=[
        dict(id="chests", name="Coffres", offers=[
            dict(id="o_chest_wood", kind="chest", ref="chest_wood", price=dict(gold=250)),
            dict(id="o_chest_reinforced", kind="chest", ref="chest_reinforced", price=dict(gold=900)),
            dict(id="o_chest_royal", kind="chest", ref="chest_royal", price=dict(crystals=200)),
            dict(id="o_chest_goblin", kind="chest", ref="chest_goblin", price=dict(crystals=150)),
            dict(id="o_chest_module", kind="chest", ref="chest_module", price=dict(crystals=180)),
            dict(id="o_chest_mutation", kind="chest", ref="chest_mutation", price=dict(gold=1500)),
        ]),
        dict(id="weapons", name="Armes", offers=[
            dict(id="o_w_bone_axe", kind="item", ref="w_bone_axe", price=dict(gold=800)),
            dict(id="o_w_pike", kind="item", ref="w_pike", price=dict(gold=800)),
            dict(id="o_w_brise_fer", kind="item", ref="w_brise_fer", price=dict(gold=3000)),
            dict(id="o_w_lance_tempete", kind="item", ref="w_lance_tempete", price=dict(gold=3000)),
            dict(id="o_w_fendoir_royal", kind="item", ref="w_fendoir_royal", price=dict(crystals=350)),
            dict(id="o_w_marteau_roi", kind="item", ref="w_marteau_roi", price=dict(crystals=900)),
            dict(id="o_w_epee_parade", kind="item", ref="w_epee_parade", price=dict(crystals=120), limit=1),
        ]),
        dict(id="armors", name="Armures", offers=[
            dict(id="o_t_leather", kind="item", ref="t_leather", price=dict(gold=700)),
            dict(id="o_h_iron_helm", kind="item", ref="h_iron_helm", price=dict(gold=600)),
            dict(id="o_le_greaves", kind="item", ref="le_greaves", price=dict(gold=1800)),
            dict(id="o_f_iron_boots", kind="item", ref="f_iron_boots", price=dict(gold=1800)),
            dict(id="o_t_plate", kind="item", ref="t_plate", price=dict(crystals=300)),
            dict(id="o_t_royal_armor", kind="item", ref="t_royal_armor", price=dict(crystals=950)),
            dict(id="o_l_royal_shield", kind="item", ref="l_royal_shield", price=dict(crystals=800)),
        ]),
        dict(id="accessories", name="Accessoires", offers=[
            dict(id="o_h_war_mask", kind="item", ref="h_war_mask", price=dict(gold=2200)),
            dict(id="o_e_red_lenses", kind="item", ref="e_red_lenses", price=dict(gold=2500)),
            dict(id="o_s_spikes", kind="item", ref="s_spikes", price=dict(gold=2200)),
            dict(id="o_ha_iron_gloves", kind="item", ref="ha_iron_gloves", price=dict(gold=2000)),
            dict(id="o_b_quiver", kind="item", ref="b_quiver", price=dict(gold=2400)),
            dict(id="o_h_royal_crown", kind="item", ref="h_royal_crown", price=dict(crystals=400)),
        ]),
        dict(id="auras", name="Auras", offers=[
            dict(id="o_a_frost", kind="item", ref="a_frost", price=dict(crystals=150), limit=1),
            dict(id="o_a_toxic", kind="item", ref="a_toxic", price=dict(crystals=300), limit=1),
            dict(id="o_a_storm", kind="item", ref="a_storm", price=dict(crystals=600), limit=1),
        ]),
        dict(id="cosmetics", name="Apparences et emotes", offers=[
            dict(id="o_emote_cross", kind="cosmetic", ref="emote_cross", price=dict(crystals=80), limit=1),
            dict(id="o_emote_roar", kind="cosmetic", ref="emote_roar", price=dict(crystals=150), limit=1),
            dict(id="o_taunt", kind="cosmetic", ref="taunt_tongue", price=dict(crystals=80), limit=1),
            dict(id="o_victory_flex", kind="cosmetic", ref="victory_flex", price=dict(crystals=200), limit=1),
            dict(id="o_entry_smoke", kind="cosmetic", ref="entry_smoke", price=dict(crystals=150), limit=1),
            dict(id="o_entry_lightning", kind="cosmetic", ref="entry_lightning", price=dict(crystals=450), limit=1),
            dict(id="o_b_banner", kind="item", ref="b_banner", price=dict(gold=2500), limit=1),
        ]),
        dict(id="event", name="Objets d'événement", offers=[
            dict(id="o_ev_ancestral", kind="chest", ref="chest_ancestral", price=dict(war_tokens=400)),
            dict(id="o_ev_l_griffe", kind="item", ref="l_griffe_traqueur", price=dict(war_tokens=250), limit=1),
            dict(id="o_ev_totem", kind="item", ref="be_totem_hurleur", price=dict(war_tokens=250), limit=1),
            dict(id="o_ev_oeil", kind="item", ref="e_oeil_pillard", price=dict(war_tokens=300), limit=1),
            dict(id="o_ev_mutation", kind="chest", ref="chest_mutation", price=dict(war_tokens=120)),
            dict(id="o_ev_larme", kind="material", ref="mat_larme_ancestrale", price=dict(war_tokens=600), limit=2),
        ]),
        dict(id="crystals", name="Cristaux (argent réel)", real_money=True, offers=[
            dict(id="o_cr_small", kind="iap", ref="crystals_80", amount=80, label_price="—"),
            dict(id="o_cr_medium", kind="iap", ref="crystals_500", amount=500, label_price="—"),
            dict(id="o_cr_large", kind="iap", ref="crystals_1200", amount=1200, label_price="—"),
        ]),
    ],
    free_daily=dict(gold=100, chest="chest_wood"),
)

# --------------------------------------------------------------------------- PASS
def build_pass():
    tiers = []
    free_cycle = [dict(gold=300), dict(fragments=30), dict(chest="chest_wood"), dict(components=40), dict(war_tokens=40),
                  dict(gold=500), dict(chest="chest_reinforced"), dict(mutant_essence=30), dict(crystals=10), dict(fragments=60)]
    premium_specials = {
        1: dict(item="w_epee_parade"), 3: dict(cosmetic="emote_cross"), 5: dict(item="a_embers"), 7: dict(item="t_mystic_robe"),
        9: dict(item="h_horned_helm_cos"), 11: dict(cosmetic="victory_flex"), 13: dict(item="w_epine_arcanique"), 15: dict(cosmetic="entry_smoke"),
        17: dict(item="b_banner"), 19: dict(cosmetic="emote_roar"), 21: dict(item="a_toxic"), 23: dict(item="s_royal"),
        25: dict(cosmetic="defeat_shrug"), 27: dict(item="le_runner"), 29: dict(item="b_wings"), 31: dict(item="a_storm"),
        33: dict(cosmetic="emote_spin"), 35: dict(item="w_faux_ombre"), 37: dict(item="h_royal_crown"), 40: dict(cosmetic="victory_throne"),
    }
    free_specials = {10: dict(chest="chest_royal"), 20: dict(item="a_embers"), 30: dict(chest="chest_module"), 40: dict(chest="chest_ancestral")}
    for i in range(1, 41):
        free = free_specials.get(i, free_cycle[(i - 1) % len(free_cycle)])
        prem = premium_specials.get(i, dict(gold=400 + 20 * i) if i % 2 == 0 else dict(crystals=15))
        tiers.append(dict(tier=i, free=free, premium=prem))
    return dict(season_id="s1", name="Saison 1 — L'Éveil des Forges", start="2026-10-01", end="2027-01-04",
                xp_per_tier=100, premium_price=dict(crystals=650), tiers=tiers,
                xp_sources=dict(battle_win=30, battle_loss=10, daily_mission=50, weekly_mission=150))

# --------------------------------------------------------------------------- MISSIONS / ACHIEVEMENTS
DAILY = [
    dict(id="d_win3", stat="battle_won", target=3, name="Gagner 3 combats", reward=dict(gold=250, crystals=5)),
    dict(id="d_collect2", stat="resources_collected", target=2, name="Collecter 2 fois vos bâtiments", reward=dict(gold=150)),
    dict(id="d_upgrade_card", stat="card_upgraded", target=1, name="Améliorer une carte", reward=dict(fragments=30)),
    dict(id="d_open_chest", stat="chest_opened", target=1, name="Ouvrir un coffre", reward=dict(gold=150, components=10)),
    dict(id="d_craft", stat="item_crafted", target=1, name="Fabriquer un module", reward=dict(components=30)),
    dict(id="d_building", stat="building_upgraded", target=1, name="Améliorer un bâtiment", reward=dict(gold=200)),
    dict(id="d_challenge", stat="challenge_won", target=1, name="Terminer un défi", reward=dict(war_tokens=40)),
    dict(id="d_deploy", stat="units_deployed", target=30, name="Déployer 30 unités", reward=dict(gold=200)),
    dict(id="d_ability", stat="king_ability_used", target=6, name="Utiliser 6 capacités du King", reward=dict(fragments=40)),
    dict(id="d_battles", stat="battle_played", target=4, name="Jouer 4 combats", reward=dict(gold=200, war_tokens=10)),
]
WEEKLY = [
    dict(id="w_boss", stat="boss_defeated", target=1, name="Vaincre un boss", reward=dict(crystals=30, chest="chest_reinforced")),
    dict(id="w_defense", stat="defense_won", target=2, name="Défendre la base 2 fois", reward=dict(gold=800, war_tokens=60)),
    dict(id="w_raids", stat="raid_won", target=3, name="Réussir 3 raids", reward=dict(gold=1000, components=60)),
    dict(id="w_unlock_card", stat="card_unlocked", target=1, name="Débloquer une carte", reward=dict(fragments=100)),
    dict(id="w_king", stat="king_upgraded", target=2, name="Améliorer le King Gobelin 2 fois", reward=dict(mutant_essence=40, crystals=20)),
    dict(id="w_win15", stat="battle_won", target=15, name="Gagner 15 combats", reward=dict(chest="chest_royal")),
]
ACHIEVEMENTS = [
    dict(id="a_first_win", stat="battle_won", target=1, name="Première victoire", reward=dict(crystals=20)),
    dict(id="a_wins_25", stat="battle_won", target=25, name="Chef de guerre", reward=dict(crystals=50)),
    dict(id="a_wins_100", stat="battle_won", target=100, name="Conquérant", reward=dict(crystals=150, chest="chest_ancestral")),
    dict(id="a_first_legendary", stat="legendary_card_owned", target=1, name="Première carte légendaire", reward=dict(crystals=50)),
    dict(id="a_first_mutation", stat="mutation_unlocked", target=1, name="Première mutation", reward=dict(mutant_essence=60)),
    dict(id="a_first_craft", stat="item_crafted", target=1, name="Premier module fabriqué", reward=dict(components=80)),
    dict(id="a_first_zone", stat="zone_unlocked", target=1, name="Première zone débloquée", reward=dict(gold=500)),
    dict(id="a_streak_5", stat="best_win_streak", target=5, name="Série de 5 victoires", reward=dict(crystals=40), mode="max"),
    dict(id="a_streak_10", stat="best_win_streak", target=10, name="Série de 10 victoires", reward=dict(item="s_trophy"), mode="max"),
    dict(id="a_boss_hunter", stat="boss_defeated", target=5, name="Chasseur de boss", reward=dict(material="mat_larme_ancestrale", crystals=30)),
    dict(id="a_raider", stat="raid_won", target=10, name="Pilleur de forteresses", reward=dict(war_tokens=200)),
    dict(id="a_campaign_done", stat="campaign_completed", target=1, name="Fin de la campagne", reward=dict(item="w_lame_ancestrale")),
    dict(id="a_all_stars", stat="campaign_stars", target=120, name="Perfection royale", reward=dict(item="a_ancestral"), mode="max"),
    dict(id="a_fortress_5", stat="fortress_level", target=5, name="Forteresse imposante", reward=dict(crystals=60), mode="max"),
    dict(id="a_survivor", stat="survival_best", target=10, name="Survivant (10 vagues)", reward=dict(chest="chest_royal"), mode="max"),
]
for fam, (fname, _) in FAMILIES.items():
    ACHIEVEMENTS.append(dict(id="a_family_" + fam, stat="family_complete_" + fam, target=1, name="Collection complète : " + fname,
                             reward=dict(crystals=40, chest="chest_goblin"), mode="max"))

# --------------------------------------------------------------------------- CAMPAIGN
BOSSES = [
    dict(id="boss_colosse", name="Colosse de Fer", hp=9000, dmg=240, hit=2.2, speed=0.7, radius=1.4, armor=60, look=dict(color="#7b7f86", scale=2.6, weapon="hammer_big", acc=["metal_plates", "chimney"]),
         desc="Armure destructible : brisez ses plaques (2500 PV) pour l'exposer et l'étourdir.",
         armor_layer=2500, phases=[
             dict(threshold=1.0, attacks=[dict(type="slam", radius=2.6, dmg=420, telegraph=1.6, cooldown=7.0)]),
             dict(threshold=0.5, speed_mult=1.2, attacks=[dict(type="slam", radius=3.0, dmg=480, telegraph=1.4, cooldown=6.0), dict(type="shockwave", radius=5.0, dmg=200, telegraph=2.0, cooldown=12.0)]),
         ]),
    dict(id="boss_reine", name="Reine des Cendres", hp=8000, dmg=160, hit=1.6, speed=0.9, radius=1.1, armor=20, range=5.0, proj=9, look=dict(color="#3a1a10", scale=2.0, weapon="staff", acc=["flame_hair", "glow", "crown_small"]),
         desc="Pluie de feu et invocation de Pyrogobelins.",
         phases=[
             dict(threshold=1.0, attacks=[dict(type="fire_rain", count=3, radius=1.8, dmg=260, telegraph=1.8, cooldown=8.0), dict(type="summon", unit="pyrogobelin", count=2, cooldown=14.0)]),
             dict(threshold=0.4, attacks=[dict(type="fire_rain", count=5, radius=1.8, dmg=280, telegraph=1.5, cooldown=6.5), dict(type="summon", unit="danseflammes", count=2, cooldown=12.0)]),
         ]),
    dict(id="boss_devoreur", name="Dévoreur Mutant", hp=11000, dmg=260, hit=1.8, speed=0.85, radius=1.5, armor=30, look=dict(color="#5a1e5e", scale=2.8, weapon="claws", acc=["big_jaw", "tentacles", "boils"]),
         desc="Change de comportement : dévore ses proies pour se soigner, puis enrage.",
         phases=[
             dict(threshold=1.0, attacks=[dict(type="devour", range=2.2, heal_pct=6, cooldown=9.0, telegraph=1.2), dict(type="slam", radius=2.4, dmg=380, telegraph=1.5, cooldown=8.0)]),
             dict(threshold=0.6, speed_mult=1.3, attacks=[dict(type="charge", dist=7.0, width=1.5, dmg=420, telegraph=1.6, cooldown=9.0), dict(type="devour", range=2.4, heal_pct=5, cooldown=10.0, telegraph=1.0)]),
             dict(threshold=0.25, speed_mult=1.5, dmg_mult=1.4, attacks=[dict(type="shockwave", radius=4.5, dmg=300, telegraph=1.6, cooldown=7.0), dict(type="charge", dist=8.0, width=1.6, dmg=460, telegraph=1.4, cooldown=8.0)]),
         ]),
    dict(id="boss_roi_exile", name="Roi Exilé", hp=12000, dmg=220, hit=1.2, speed=1.2, radius=1.1, armor=35, look=dict(color="#4a3a5a", scale=1.9, weapon="axe_big", acc=["crown_small", "cape", "glow"]),
         desc="Un ancien King : Frappe du Tyran, Rugissement royal et Appel des Pillards.",
         phases=[
             dict(threshold=1.0, attacks=[dict(type="tyrant_strike", radius=2.6, dmg=400, telegraph=1.2, cooldown=8.0), dict(type="royal_roar", radius=6.0, pct=30, cooldown=16.0)]),
             dict(threshold=0.5, attacks=[dict(type="tyrant_strike", radius=3.0, dmg=450, telegraph=1.0, cooldown=6.5), dict(type="summon", unit="pillard", count=2, cooldown=12.0), dict(type="royal_roar", radius=6.0, pct=35, cooldown=14.0)]),
         ]),
    dict(id="boss_dernier_roi", name="Le Dernier Roi", hp=16000, dmg=280, hit=1.3, speed=1.0, radius=1.4, armor=40, look=dict(color="#f0e0a0", scale=2.4, weapon="sword_big", acc=["crown_small", "cape", "glow", "runes"]),
         desc="L'ultime souverain de Varkon. Trois phases, toutes les mécaniques réunies.",
         armor_layer=3000, phases=[
             dict(threshold=1.0, attacks=[dict(type="slam", radius=2.8, dmg=420, telegraph=1.4, cooldown=7.0), dict(type="fire_rain", count=3, radius=1.8, dmg=240, telegraph=1.8, cooldown=10.0)]),
             dict(threshold=0.66, attacks=[dict(type="charge", dist=8.0, width=1.6, dmg=450, telegraph=1.5, cooldown=8.0), dict(type="summon", unit="garde_trone", count=2, cooldown=16.0)]),
             dict(threshold=0.33, speed_mult=1.3, dmg_mult=1.3, attacks=[dict(type="shockwave", radius=5.0, dmg=320, telegraph=1.6, cooldown=7.0), dict(type="fire_rain", count=6, radius=1.6, dmg=260, telegraph=1.4, cooldown=7.0), dict(type="royal_roar", radius=6.0, pct=40, cooldown=15.0)]),
         ]),
]

CHAPTERS = [
    dict(id=1, name="Les Collines Rouillées", desc="Les tribus voisines testent vos défenses.", families=["raider", "wild", "fire"], boss="boss_colosse"),
    dict(id=2, name="Les Forges de Cendre", desc="Au cœur des volcans, la Reine des Cendres règne.", families=["fire", "mech", "raider"], boss="boss_reine"),
    dict(id=3, name="Le Marais Mutant", desc="Des créatures difformes rôdent dans les brumes.", families=["toxic", "mutant", "shadow"], boss="boss_devoreur"),
    dict(id=4, name="Les Cimes Gelées", desc="Le Roi Exilé a rassemblé une armée dans la glace.", families=["ice", "air", "royal"], boss="boss_roi_exile"),
    dict(id=5, name="Le Trône des Failles", desc="La relique ultime vous attend : la couronne du Dernier Roi.", families=["mystic", "royal", "shadow", "mutant"], boss="boss_dernier_roi"),
]

TYPE_PLAN = ["duel", "duel", "duel", "raid", "defense", "challenge", "duel", "boss"]
TIPS = {
    "c1m1": "Faites glisser une carte sur votre moitié du terrain pour déployer une unité.",
    "c1m2": "Touchez le sol pour déplacer votre King Gobelin, puis utilisez sa compétence active.",
    "c1m3": "Détruisez les tours ennemies avant d'attaquer le Trône.",
    "c1m4": "Raid : détruisez le Trône de la forteresse ennemie avant la fin du temps. Les murailles bloquent les unités terrestres.",
    "c1m5": "Défense : survivez aux vagues. Vos murailles, pièges et tours de garde de la base sont présents.",
    "c1m6": "Défi : seules certaines cartes sont autorisées. Lisez les règles.",
    "c1m8": "Boss : évitez les zones rouges annoncées et frappez pendant ses phases d'épuisement.",
}
CHALLENGE_MODS = [
    dict(only_families=["raider", "wild"], text="Seulement des cartes Pillards et Sauvages"),
    dict(energy_rate=2.0, text="Rage double pendant tout le combat"),
    dict(no_hero=True, text="Sans King Gobelin"),
    dict(max_cost=4, text="Cartes de coût 4 maximum"),
    dict(enemy_double_hp=True, text="Tours ennemies renforcées (x2 PV)"),
]


def build_campaign():
    missions = []
    card_ids_by_fam = {}
    for c in C:
        card_ids_by_fam.setdefault(c["family"], []).append(c)
    for ch in CHAPTERS:
        pool = [c for f in ch["families"] for c in card_ids_by_fam[f]]
        for i in range(8):
            mid = "c%dm%d" % (ch["id"], i + 1)
            mtype = TYPE_PLAN[i]
            progress = (ch["id"] - 1) * 8 + i  # 0..39
            diff = "easy" if progress < 10 else ("normal" if progress < 26 else "expert")
            lvl = 1 + progress // 4
            max_unlock = 1 + progress // 2
            eligible = sorted([c for c in pool if c["unlock_level"] <= max_unlock + 2], key=lambda c: (c["cost"], c["id"]))
            if len(eligible) < 8:
                eligible = sorted(pool, key=lambda c: (c["unlock_level"], c["cost"]))[:10]
            # deterministic but varied deck
            deck = []
            k = i * 3
            while len(deck) < 8:
                cand = eligible[k % len(eligible)]["id"]
                if cand not in deck:
                    deck.append(cand)
                k += 5
                if k > 400:
                    break
            for extra in ["pillard", "frondeur", "croquefer", "givregriffes", "venin", "boulon", "pyrogobelin", "medecin_guerre"]:
                if len(deck) >= 8:
                    break
                if extra not in deck:
                    deck.append(extra)
            m = dict(id=mid, chapter=ch["id"], index=i + 1, type=mtype, difficulty=diff, enemy_level=lvl,
                     enemy_deck=deck, enemy_hero=(mtype in ("duel", "challenge") and progress >= 1) or (mtype == "raid" and ch["id"] >= 3),
                     name="", tip=TIPS.get(mid, ""),
                     rewards=dict(gold=120 + 40 * progress, xp=40 + 8 * progress),
                     first_clear=dict(crystals=10 + 2 * progress, chest="chest_victory" if mtype != "boss" else "chest_royal"),
                     requires=("c%dm%d" % (ch["id"], i) if i > 0 else ("c%dm8" % (ch["id"] - 1) if ch["id"] > 1 else None)))
            names = {"duel": "Escarmouche", "raid": "Raid", "defense": "Siège", "challenge": "Épreuve", "boss": "Affrontement"}
            places = {
                1: ["du Col Rouillé", "de la Rive Grise", "des Ruines Brisées", "du Bastion Ferreux", "du Ravin Sanglant", "du Sanctuaire Oublié", "de la Tour Noire", "final"],
                2: ["des Coulées de Lave", "de la Forge Brûlée", "du Pont de Cendre", "du Fort Écarlate", "des Fumerolles", "du Brasier", "de l'Enclume", "final"],
                3: ["des Marécages", "du Bois Pourri", "de la Mare Verte", "du Repaire Fongique", "des Spores", "du Gouffre Mutant", "des Racines Noires", "final"],
                4: ["du Glacier", "des Pics Blancs", "de la Crevasse", "de la Citadelle de Givre", "du Blizzard", "des Vents Hurlants", "du Trône de Glace", "final"],
                5: ["de la Faille", "du Vide", "des Runes Brisées", "du Palais Déchu", "de l'Éclipse", "des Anciens", "du Dernier Seuil", "final"],
            }[ch["id"]]
            m["name"] = "%s %s" % (names[mtype], places[i])
            if mtype == "boss":
                m["boss"] = ch["boss"]
                m["name"] = next(b["name"] for b in BOSSES if b["id"] == ch["boss"])
                m["rewards"]["gold"] += 300
            if mtype == "defense":
                waves = []
                for w in range(3 + ch["id"] // 2):
                    waves.append(dict(delay=4.0 if w == 0 else 14.0, units=[deck[(w * 2 + j) % len(deck)] for j in range(2 + w + ch["id"] // 2)]))
                m["waves"] = waves
            if mtype == "challenge":
                m["modifiers"] = CHALLENGE_MODS[(ch["id"] - 1) % len(CHALLENGE_MODS)]
            if mtype == "raid":
                m["layout"] = "raid_%d" % (1 + (ch["id"] - 1) % 3)
            missions.append(m)
    # Specific first clear rewards to introduce systems/cards
    special = {"c1m2": dict(card="ragecornes"), "c1m3": dict(card="lance_givre"), "c1m4": dict(card="kamikaze"), "c1m8": dict(chest="chest_module"),
               "c2m3": dict(card="ferrailleur"), "c2m5": dict(card="ingenieur_terrain"), "c2m8": dict(item="w_brise_fer"), "c3m4": dict(item="r_coeur_fourneau"),
               "c3m8": dict(item="w_croc_mythique", material="mat_larme_ancestrale"), "c4m8": dict(item="t_ancestral"), "c5m8": dict(item="h_couronne_dernier_roi", chest="chest_ancestral")}
    for m in missions:
        if m["id"] in special:
            m["first_clear"].update(special[m["id"]])
    # Couronne du Dernier Roi requires 3 stars on the final mission: mark it
    for m in missions:
        if m["id"] == "c5m8":
            m["three_star_reward"] = dict(item="h_couronne_dernier_roi")
            m["first_clear"].pop("item", None)
    return missions


RAID_LAYOUTS = {
    "raid_1": dict(towers=[[25, 4], [25, 14]], walls=[[22, y] for y in range(3, 16, 1)], traps=[[20, 7], [20, 11]], extra_towers=[]),
    "raid_2": dict(towers=[[25, 4], [25, 14], [28, 9]], walls=[[22, y] for y in range(2, 8)] + [[22, y] for y in range(11, 17)] + [[26, y] for y in range(7, 12)], traps=[[22, 9], [20, 5], [20, 13]], extra_towers=[[23, 9]]),
    "raid_3": dict(towers=[[24, 3], [24, 15], [27, 6], [27, 12]], walls=[[21, y] for y in range(2, 17)] + [[26, y] for y in range(4, 15)], traps=[[19, 6], [19, 9], [19, 12], [23, 9]], extra_towers=[[23, 9]]),
}

EVENTS = [
    dict(id="ev_mech_invasion", name="Invasion mécanique", desc="Repoussez des vagues d'unités mécaniques.", type="defense", families=["mech"], reward=dict(war_tokens=80, chest="chest_module"), difficulty="normal"),
    dict(id="ev_fire_week", name="Semaine des gobelins de feu", desc="Combats avec cartes de feu uniquement ; les unités de feu ennemies sont renforcées.", type="challenge", families=["fire"], modifiers=dict(only_families=["fire"], text="Cartes de feu uniquement"), reward=dict(war_tokens=80, chest="chest_reinforced"), difficulty="normal"),
    dict(id="ev_mutation", name="Défi de mutation", desc="Affrontez une armée mutante.", type="duel", families=["mutant", "toxic"], reward=dict(war_tokens=80, chest="chest_mutation"), difficulty="normal"),
    dict(id="ev_boss_hunt", name="Chasse au boss", desc="Affrontez un boss aléatoire.", type="boss", reward=dict(war_tokens=120, chest="chest_royal"), difficulty="expert"),
    dict(id="ev_defense", name="Défi de défense", desc="Tenez 6 vagues.", type="defense", families=["raider", "wild"], reward=dict(war_tokens=100, chest="chest_reinforced"), difficulty="expert"),
    dict(id="ev_collection", name="Événement de collection", desc="Gagnez avec au moins 4 familles différentes dans votre deck.", type="duel", families=["royal", "mystic"], modifiers=dict(min_families=4, text="Au moins 4 familles différentes"), reward=dict(war_tokens=80, chest="chest_goblin"), difficulty="normal"),
    dict(id="ev_king_trial", name="Épreuve du King Gobelin", desc="Votre King seul, sans cartes, contre des vagues.", type="defense", families=["raider"], modifiers=dict(no_cards=True, text="Aucune carte : King uniquement"), reward=dict(war_tokens=120, chest="chest_module"), difficulty="normal"),
]

PLAYER = dict(
    xp_curve=[0, 100, 250, 450, 700, 1000, 1400, 1900, 2500, 3200, 4000, 5000, 6200, 7600, 9200, 11000, 13000, 15500, 18500, 22000],
    level_rewards=dict(gold=300, crystals=10),
    start_resources=dict(gold=600, crystals=60, fragments=20, components=30, mutant_essence=0, war_tokens=0, ancestral=0),
    start_cards=["pillard", "frondeur", "pyrogobelin", "givregriffes", "croquefer", "boulon", "venin", "medecin_guerre", "porte_bouclier", "aile_griffe"],
    start_deck=["pillard", "frondeur", "pyrogobelin", "givregriffes", "croquefer", "boulon", "medecin_guerre", "aile_griffe"],
    start_items=["w_rusty_blade", "l_buckler", "h_leather_cap", "t_rags", "ha_wraps", "le_trousers", "f_sandals", "be_rope"],
    start_cosmetics=["emote_laugh", "emote_smash", "victory_jump"],
    loadout_slots=[dict(level=1, slots=2), dict(level=6, slots=3), dict(level=12, slots=4)],
    battle=dict(duration=180, overtime=60, energy_start=5, energy_max=10, energy_regen=2.8, hand_size=4, deck_size=8,
                hero_respawn=12.0, ultimate_charge_per_sec=1.0, ultimate_charge_per_dmg=0.02),
    battle_rewards=dict(win_gold=[60, 120], loss_gold=[15, 30], win_xp=30, loss_xp=10, victory_chest_chance=35, war_tokens_challenge=20),
)

STRUCTURES = dict(
    throne=dict(hp=4200, dmg=110, hit=1.0, range=7.5, radius=1.5, proj=12),
    tower=dict(hp=2400, dmg=90, hit=0.9, range=7.0, radius=0.9, proj=14),
    wall=dict(hp=600, radius=0.55),
    trap=dict(dmg=220, radius=1.2),
    dummy=dict(hp=6000, radius=0.6),
)


def main():
    os.makedirs(OUT, exist_ok=True)
    cards, tokens = build_cards()
    assert len(cards) >= 70, len(cards)
    ids = [c["id"] for c in cards]
    assert len(ids) == len(set(ids)), "duplicate card id"
    item_ids = [i["id"] for i in ITEMS]
    assert len(item_ids) == len(set(item_ids)), "duplicate item id"
    for r in RECIPES:
        assert r["item"] in item_ids, r
    files = {
        "cards.json": dict(cards=cards, tokens=tokens, families={k: dict(name=v[0], color=v[1]) for k, v in FAMILIES.items()},
                           rarities=RARITIES, upgrade=CARD_UPGRADE, synergies=SYNERGIES),
        "items.json": dict(slots=[dict(id=s, name=n, unlock=SLOT_UNLOCK[s]) for s, n in SLOTS], items=ITEMS, cosmetics=COSMETICS, materials=MATERIALS),
        "king.json": dict(KING, mutations=MUTATIONS),
        "buildings.json": dict(buildings=BUILDINGS, zones=ZONES, grid=GRID, start=START_BASE),
        "lab.json": dict(LAB, research=RESEARCH, recipes=RECIPES),
        "economy.json": dict(resources=RESOURCES, chests=CHESTS, shop=SHOP, player=PLAYER),
        "pass.json": build_pass(),
        "missions.json": dict(daily=DAILY, weekly=WEEKLY, achievements=ACHIEVEMENTS, daily_count=3, weekly_count=3),
        "campaign.json": dict(chapters=CHAPTERS, missions=build_campaign(), bosses=BOSSES, raid_layouts=RAID_LAYOUTS, events=EVENTS, structures=STRUCTURES),
    }
    for name, content in files.items():
        with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
            json.dump(content, f, ensure_ascii=False, indent=1)
        print("wrote", name)
    print("cards:", len(cards), "items:", len(ITEMS), "cosmetics:", len(COSMETICS), "missions:", len(files["campaign.json"]["missions"]))


if __name__ == "__main__":
    main()
