import 'package:flutter/material.dart';

/// Static knowledge base behind the Beginner Fan Hub and the Fandom Glossary.

class GlossaryTerm {
  const GlossaryTerm({
    required this.term,
    required this.definition,
    required this.category,
  });

  final String term;
  final String definition;
  final String category;

  String get letter => term.isEmpty
      ? '#'
      : (term[0].toUpperCase().contains(RegExp(r'[A-Z]'))
          ? term[0].toUpperCase()
          : '#');
}

const List<GlossaryTerm> kGlossaryTerms = [
  GlossaryTerm(
    term: 'AU',
    definition:
        'Alternate Universe — a fan work that keeps the characters but moves '
        'them into a different setting, like a coffee shop or a fantasy realm.',
    category: 'Fan Fiction',
  ),
  GlossaryTerm(
    term: 'BL',
    definition:
        'Boys\' Love — romance stories between male characters; a widely used '
        'genre label in manga, anime and fan fiction.',
    category: 'Fan Fiction',
  ),
  GlossaryTerm(
    term: 'BNF',
    definition:
        'Big Name Fan — a well-known community member whose work or presence '
        'influences the fandom.',
    category: 'Fandom 101',
  ),
  GlossaryTerm(
    term: 'Canon',
    definition:
        'The official, source-material story. If it happened in the original '
        'work, it is canon.',
    category: 'Fandom 101',
  ),
  GlossaryTerm(
    term: 'Character Arc',
    definition:
        'The journey a character takes across a story — how they change from '
        'the first episode to the last.',
    category: 'Writing & Tropes',
  ),
  GlossaryTerm(
    term: 'Cliffhanger',
    definition:
        'An ending that deliberately leaves a question open so you *have* to '
        'watch the next episode.',
    category: 'Writing & Tropes',
  ),
  GlossaryTerm(
    term: 'Con',
    definition:
        'Short for convention — a fan gathering with panels, merch booths, '
        'cosplay and often guest stars from the show.',
    category: 'Conventions',
  ),
  GlossaryTerm(
    term: 'Cosplay',
    definition:
        'Dressing up as a character. "Cosplay" covers everything from a quick '
        'thrift-store build to months of armour crafting.',
    category: 'Conventions',
  ),
  GlossaryTerm(
    term: 'Crack',
    definition:
        'A deliberately silly fan work that leans into absurdity for comedy — '
        'logic optional, fun mandatory.',
    category: 'Fan Fiction',
  ),
  GlossaryTerm(
    term: 'Dead Dove: Do Not Eat',
    definition:
        'A tag warning readers that a story contains exactly what the summary '
        'says — no surprises, read at your own risk.',
    category: 'Fan Fiction',
  ),
  GlossaryTerm(
    term: 'Doujinshi',
    definition:
        'Self-published fan comics or zines, usually made by fans of an '
        'existing series.',
    category: 'Fan Fiction',
  ),
  GlossaryTerm(
    term: 'Fan Art',
    definition:
        'Art made by fans of a show, game or character — illustrations, '
        'prints, crafts and everything between.',
    category: 'Fan Creation',
  ),
  GlossaryTerm(
    term: 'Fan Fiction',
    definition:
        'Stories written by fans using characters or worlds from an existing '
        'work. Also: fanfic, fic, ficlet.',
    category: 'Fan Fiction',
  ),
  GlossaryTerm(
    term: 'Fandom',
    definition:
        'The community of people who love the same thing — and everything '
        'they create together.',
    category: 'Fandom 101',
  ),
  GlossaryTerm(
    term: 'Fanon',
    definition:
        'Beliefs or details the fandom widely accepts even though they were '
        'never confirmed by the official work.',
    category: 'Fandom 101',
  ),
  GlossaryTerm(
    term: 'Filler',
    definition:
        'An episode that skips the main plot — often a beach episode or a '
        'recap. Skippable, sometimes iconic.',
    category: 'Anime & Manga',
  ),
  GlossaryTerm(
    term: 'Headcanon',
    definition:
        'Your personal version of events or character details that the '
        'canon never addressed.',
    category: 'Fandom 101',
  ),
  GlossaryTerm(
    term: 'Isekai',
    definition:
        'A genre where a character is transported into another world — '
        'typically a game or fantasy realm.',
    category: 'Anime & Manga',
  ),
  GlossaryTerm(
    term: 'Lore',
    definition:
        'The deep history and background of a fictional world — the part you '
        'wiki at 2 AM.',
    category: 'Writing & Tropes',
  ),
  GlossaryTerm(
    term: 'Mary Sue',
    definition:
        'A character who is effortlessly perfect and loved by everyone — a '
        'classic amateur-writing pitfall.',
    category: 'Writing & Tropes',
  ),
  GlossaryTerm(
    term: 'Meta',
    definition:
        'Analysis of the work itself — themes, symbolism, patterns — or a '
        'story set in a world where the fandom exists.',
    category: 'Fandom 101',
  ),
  GlossaryTerm(
    term: 'Oneshot',
    definition:
        'A complete fan story that fits in a single chapter — no commitment, '
        'all payoff.',
    category: 'Fan Fiction',
  ),
  GlossaryTerm(
    term: 'OTP',
    definition:
        'One True Pairing — your absolute favourite ship for a character or '
        'series.',
    category: 'Shipping',
  ),
  GlossaryTerm(
    term: 'Otaku',
    definition:
        'A deeply devoted fan, especially of anime and manga. Pride '
        'optional, enthusiasm required.',
    category: 'Fandom 101',
  ),
  GlossaryTerm(
    term: 'Plot Armor',
    definition:
        'The unexplained survival of a main character no matter how doomed '
        'the situation looks.',
    category: 'Writing & Tropes',
  ),
  GlossaryTerm(
    term: 'Retcon',
    definition:
        'A retroactive change — new canon that quietly rewrites something '
        'older.',
    category: 'Fandom 101',
  ),
  GlossaryTerm(
    term: 'Self-Insert',
    definition:
        'A story where the author (or reader) appears as a character inside '
        'the fictional world.',
    category: 'Fan Fiction',
  ),
  GlossaryTerm(
    term: 'Ship',
    definition:
        'To support a romantic pairing of characters. "Shipping" is the act; '
        'a ship is the pairing itself.',
    category: 'Shipping',
  ),
  GlossaryTerm(
    term: 'Ship War',
    definition:
        'A fandom argument over which ship is canon or superior. Bring '
        'popcorn, leave the flamethrower.',
    category: 'Shipping',
  ),
  GlossaryTerm(
    term: 'Ship Tease',
    definition:
        'Canon moments that flirt with a pairing without actually confirming '
        'it — delicious and dangerous.',
    category: 'Shipping',
  ),
  GlossaryTerm(
    term: 'Slash',
    definition:
        'Fan fiction pairing characters of the same gender — a long-standing '
        'term in fan communities.',
    category: 'Shipping',
  ),
  GlossaryTerm(
    term: 'Spoiler',
    definition:
        'A reveal from later in the story. Tagging spoilers is basic fandom '
        'courtesy.',
    category: 'Fandom 101',
  ),
  GlossaryTerm(
    term: 'Stan',
    definition:
        'An intensely devoted fan of a person or franchise — supportive to a '
        'fault.',
    category: 'Fandom 101',
  ),
  GlossaryTerm(
    term: 'Trope',
    definition:
        'A recurring storytelling device — "the chosen one", "enemies to '
        'lovers", "the mentor dies".',
    category: 'Writing & Tropes',
  ),
  GlossaryTerm(
    term: 'Waifu / Husbando',
    definition:
        'A tongue-in-cheek term for a favourite character you claim as your '
        'own. Do not fight over mine.',
    category: 'Shipping',
  ),
  GlossaryTerm(
    term: 'Worldbuilding',
    definition:
        'Crafting the rules of a fictional world — its history, magic, '
        'politics and physics.',
    category: 'Writing & Tropes',
  ),
  GlossaryTerm(
    term: 'Zine',
    definition:
        'A fan-made publication collecting art, essays or fiction, often '
        'sold at conventions.',
    category: 'Fan Creation',
  ),
];

class FanGuide {
  const FanGuide({
    required this.title,
    required this.blurb,
    required this.steps,
    required this.icon,
  });

  final String title;
  final String blurb;
  final List<String> steps;
  final IconData icon;
}

const List<FanGuide> kFanGuides = [
  FanGuide(
    title: 'Find your fandom',
    blurb: 'From a first episode to your people in under five minutes.',
    icon: Icons.explore_outlined,
    steps: [
      'Pick one show, game or series you already enjoy — no homework.',
      'Open Explore and search its name to see what the fandom is writing about.',
      'Join a community and read a few posts before introducing yourself.',
      'Follow a couple of creators whose posts make you laugh or think.',
      'Save discoveries with the bookmark icon — they land in your Saved shelf.',
    ],
  ),
  FanGuide(
    title: 'Your first convention',
    blurb: 'Panels, merch and cosplay without the overwhelm.',
    icon: Icons.confirmation_number_outlined,
    steps: [
      'Check the event calendar here in the app and grab tickets early.',
      'Plan two or three must-see panels — leave gaps for wandering.',
      'Pack light: water, a phone charger, a tote for merch, comfy shoes.',
      'Cosplay is optional. Courtesy is not — ask before photos.',
      'Set a budget before the artist alley. Future you will say thanks.',
    ],
  ),
  FanGuide(
    title: 'Fan fiction without fear',
    blurb: 'Reading and writing fan stories, start to finish.',
    icon: Icons.menu_book_outlined,
    steps: [
      'Read widely first — tags and ratings are your compass.',
      'Start with oneshots: complete stories, zero commitment.',
      'When writing, tag honestly: ratings, warnings, pairings.',
      'Consent culture applies to characters too — check the tags you use.',
      'Comments are oxygen. Leave one for an author who made your day.',
    ],
  ),
  FanGuide(
    title: 'Shipping without the ship war',
    blurb: 'Love your pairing, keep the peace.',
    icon: Icons.favorite_outline,
    steps: [
      'Your OTP is valid. So is everyone else\'s.',
      'Use mute and block tools instead of arguing in replies.',
      'Tag your ships when you post so the right people find you.',
      'Canon is one interpretation among many — argue with joy, not malice.',
      'If a thread is getting heated, touch grass and come back kinder.',
    ],
  ),
  FanGuide(
    title: 'Fan art starter pack',
    blurb: 'From first sketch to sharing online.',
    icon: Icons.brush_outlined,
    steps: [
      'Any tool counts — pencil, free tablet app, or a borrowed stylus.',
      'Redraw a scene you love; study composition while you copy.',
      'Post with the character and series named so fans can find it.',
      'Credit artists when sharing — never repost without permission.',
      'Watermark big pieces before selling prints at a con.',
    ],
  ),
  FanGuide(
    title: 'Safety & netiquette',
    blurb: 'Enjoy the verse and keep it welcoming.',
    icon: Icons.shield_outlined,
    steps: [
      'Mark spoilers — the next episode is not everyone\'s yet.',
      'Keep personal details (location, school, schedule) private.',
      'Block and report early; you owe no one a debate.',
      'Disagree about media, never about people\'s worth.',
      'Take breaks. The fandom will still be here tomorrow.',
    ],
  ),
];
