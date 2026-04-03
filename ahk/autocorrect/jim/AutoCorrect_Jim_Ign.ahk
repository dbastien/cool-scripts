;------------------------------------------------------------------------------
; Fix for -ign instead of -ing.
; Words to exclude: (could probably do this by return without rewrite)
; From: http://www.morewords.com/e nds-with/gn/
;------------------------------------------------------------------------------
#Hotstring B0  ; Turns off automatic backspacing for the following hotstrings.
::align::
::antiforeign::
::arraign::
::assign::
::benign::
::campaign::
::champaign::
::codesign::
::coign::
::condign::
::consign::
::coreign::
::cosign::
::countercampaign::
::countersign::
::deign::
::deraign::
::design::
::eloign::
::ensign::
::feign::
::foreign::
::indign::
::malign::
::misalign::
::outdesign::
::overdesign::
::preassign::
::realign::
::reassign::
::redesign::
::reign::
::resign::
::sign::
::sovereign::
::unbenign::
::verisign::
return  ; This makes the above hotstrings do nothing so that they override the ign->ing rule below.

#Hotstring B  ; Turn back on automatic backspacing for all subsequent hotstrings.
:B0?:ign::f("ing")
