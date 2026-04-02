#Requires AutoHotkey v2.0
#SingleInstance Force

; Replaces rough language with milder wording after the trigger + an ending
; character (space, punctuation, Enter). Edit freely; longer phrases first
; where a shorter word is a prefix (e.g. fucking before fuck).

; --- phrases ---
::what the fuck::what the heck
::what the hell::what the heck
::holy shit::holy cow
::pissed off::ticked off
::piss off::go away
; no bare "piss" — it would break "piss off"
::god damn::dang
::goddamn::dang
::damn it::dang it
::dammit::dang it
::piece of shit::real mess
::son of a bitch::son of a gun
::bullshit::baloney
::dumb ass::silly goose
::dumbass::silly goose
::jackass::jerk
::smartass::smart aleck
::badass::tough cookie
::hard ass::hard case
::fat ass::large person
::kiss my ass::take a hike
::pain in the ass::pain in the neck
::pain in the butt::pain in the neck
::up yours::oh, buzz off
::screw you::forget you
::fuck off::go away
::fuck you::leave me alone
::clusterfuck::total mess
::rat bastard::real jerk

; --- words (strong → softer) ---
::motherfucker::jerk
::motherfucking::freaking
::bullshitter::fibber
::shithead::jerk
::shitty::lousy
::shitting::freaking out over
::shit::shoot
::fucking::freaking
::fucked up::messed up
::fucked::messed
::fucker::jerk
::fuck::fudge
::bitchy::snippy
::bitch::jerk
::bastard::jerk
::asshole::jerk
::arsehole::jerk
::dickhead::jerk
::dickish::jerky
::dick::jerk
::cocksucker::jerk
::prick::jerk
::twat::jerk
::wanker::jerk
::douchebag::jerk
::douche::jerk
::crap::crud
::damn::darn
::hell::heck
::bastards::jerks
::bitches::jerks
::asses::butts

; --- abbreviations / netspeak ---
::wtf::what the heck
::wth::what the heck
::omfg::oh my goodness
::stfu::zip it
::gtfo::go away
::fml::rough day
::ffs::for crying out loud
