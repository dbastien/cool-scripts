#Requires AutoHotkey v2.0
#SingleInstance Force

; Expands casual / netspeak and a few letter-style abbreviations after you type
; the shorthand and an ending character (space, period, comma, Enter, etc.).

; --- casual / internet ---
::idk::I don't know
::idc::I don't care
::iirc::if I remember correctly
::imo::in my opinion
::imho::in my humble opinion
::fwiw::for what it's worth
::tbh::to be honest
::ngl::not gonna lie
::tbf::to be fair
::fyi::for your information
::aka::also known as
::wdym::what do you mean
::ikr::I know, right?
::rn::right now
::bc::because
::tho::though
::pls::please
::plz::please
::thx::thanks
::ty::thank you
::np::no problem
::yw::you're welcome
::sry::sorry
::obvi::obviously
::def::definitely
::prob::probably
::prolly::probably
::gonna::going to
::wanna::want to
::kinda::kind of
::sorta::sort of
::dunno::don't know
::cuz::because
::til::today I learned
::afaik::as far as I know
::asap::as soon as possible
::eta::estimated time of arrival
::ttyl::talk to you later
::brb::be right back
::afk::away from keyboard
::omw::on my way
::lmk::let me know
::nvm::never mind
::jk::just kidding
::irl::in real life
::ftw::for the win
::ftr::for the record
::btw::by the way
::wrt::with respect to
::tldr::tl`;dr

; --- letter / telegram-ish (longer triggers to avoid collisions) ---
::postscript::P.S.
::regards::Best regards,
::kindregards::Kind regards,
::yrssinc::Yours sincerely,
::yrstruly::Yours truly,
::recd::received
::ansg::answer by return
::refg::in reference to your
::shdl::should
::wld::would
::cld::could
::abt::about
::acct::account
::addr::address
::bcoz::because
::dept::department
::govt::government
::misc::miscellaneous
::mth::month
::pple::people
::qt::quantity
::wk::week
::ytd::year to date

; "without" shorthand (avoided w/o — can mangle paths)
::wout::without
