# ------------------------------------------------------------------------------
#  dynhelp.tcl
#  This file is part of Unifix BWidget Toolkit
#  $Id: dynhelp.tcl,v 1.10 2003/01/26 10:55:31 damonc Exp $
# ------------------------------------------------------------------------------
#  Index of commands:
#     - DynamicHelp::configure
#     - DynamicHelp::include
#     - DynamicHelp::sethelp
#     - DynamicHelp::register
#     - DynamicHelp::_motion_balloon
#     - DynamicHelp::_motion_info
#     - DynamicHelp::_leave_info
#     - DynamicHelp::_menu_info
#     - DynamicHelp::_show_help
#     - DynamicHelp::_init
# ------------------------------------------------------------------------------

# JDC: allow variable and ballon help at the same timees

namespace eval DynamicHelp {
    Widget::declare DynamicHelp {
        {-foreground  TkResource black         0 label}
        {-background  TkResource "#FFFFC0"     0 label}
        {-borderwidth TkResource 1             0 label}
        {-justify     TkResource left          0 label}
        {-font        TkResource "helvetica 8" 0 label}
        {-delay       Int        600           0 "%d >= 100 & %d <= 2000"}
	{-state       Enum       "normal"      0 {normal disabled}}
        {-bd          Synonym    -borderwidth}
        {-bg          Synonym    -background}
        {-fg          Synonym    -foreground}
    }

    proc use {} {}

    variable _registered

    variable _top     ".help_shell"
    variable _id      "" 
    variable _delay   600
    variable _current_balloon ""
    variable _current_variable ""
    variable _saved

    Widget::init DynamicHelp $_top {}

    bind BwHelpBalloon <Enter>   {DynamicHelp::_motion_balloon enter  %W %X %Y}
    bind BwHelpBalloon <Motion>  {DynamicHelp::_motion_balloon motion %W %X %Y}
    bind BwHelpBalloon <Leave>   {DynamicHelp::_motion_balloon leave  %W %X %Y}
    bind BwHelpBalloon <Button>  {DynamicHelp::_motion_balloon button %W %X %Y}
    bind BwHelpBalloon <Destroy> {if {[info exists DynamicHelp::_registered(%W,balloon)]} {unset DynamicHelp::_registered(%W,balloon)}}

    bind BwHelpVariable <Enter>   {DynamicHelp::_motion_info %W}
    bind BwHelpVariable <Motion>  {DynamicHelp::_motion_info %W}
    bind BwHelpVariable <Leave>   {DynamicHelp::_leave_info  %W}
    bind BwHelpVariable <Destroy> {if {[info exists DynamicHelp::_registered(%W,variable)]} {unset DynamicHelp::_registered(%W,variable)}}

    bind BwHelpMenu <<MenuSelect>> {DynamicHelp::_menu_info select %W}
    bind BwHelpMenu <Unmap>        {DynamicHelp::_menu_info unmap  %W}
    bind BwHelpMenu <Destroy>      {if {[info exists DynamicHelp::_registered(%W)]} {unset DynamicHelp::_registered(%W)}}
}


# ------------------------------------------------------------------------------
#  Command DynamicHelp::configure
# ------------------------------------------------------------------------------
proc DynamicHelp::configure { args } {
    variable _top
    variable _delay

    set res [Widget::configure $_top $args]
    if { [Widget::hasChanged $_top -delay val] } {
        set _delay $val
    }

    return $res
}


# ------------------------------------------------------------------------------
#  Command DynamicHelp::include
# ------------------------------------------------------------------------------
proc DynamicHelp::include { class type } {
    set helpoptions [list \
	    [list -helptext String "" 0] \
	    [list -helpvar  String "" 0] \
	    [list -helptype Enum $type 0 [list balloon variable]] \
	    ]
    Widget::declare $class $helpoptions
}


# ------------------------------------------------------------------------------
#  Command DynamicHelp::sethelp
# ------------------------------------------------------------------------------
proc DynamicHelp::sethelp { path subpath {force 0}} {
    foreach {ctype ctext cvar} [Widget::hasChangedX $path \
	    -helptype -helptext -helpvar] break
    if { $force || $ctype || $ctext || $cvar } {
	set htype [Widget::cget $path -helptype]
        switch $htype {
            balloon {
                return [register $subpath balloon \
			[Widget::cget $path -helptext]]
            }
            variable {
                return [register $subpath variable \
			[Widget::cget $path -helpvar] \
			[Widget::cget $path -helptext]]
            }
        }
        return [register $subpath $htype]
    }
}


# ------------------------------------------------------------------------------
#  Command DynamicHelp::register
# ------------------------------------------------------------------------------
proc DynamicHelp::register { path type args } {
    variable _registered

    if { [winfo exists $path] } {
        set evt  [bindtags $path]
        switch $type {
            balloon {
		set idx  [lsearch $evt "BwHelpBalloon"]
		set evt  [lreplace $evt $idx $idx]
                set text [lindex $args 0]
                if { $text != "" } {
                    set _registered($path,balloon) $text
                    lappend evt BwHelpBalloon
                } else {
                    if {[info exists _registered($path,balloon)]} {
                        unset _registered($path,balloon)
                    }
                }
                bindtags $path $evt
                return 1
            }

            variable {
		set idx  [lsearch $evt "BwHelpVariable"]
		set evt  [lreplace $evt $idx $idx]
                set var  [lindex $args 0]
                set text [lindex $args 1]
                if { $text != "" && $var != "" } {
                    set _registered($path,variable) [list $var $text]
                    lappend evt BwHelpVariable
                } else {
                    if {[info exists _registered($path,variable)]} { 
                        unset _registered($path,variable)
                    }
                }
                bindtags $path $evt
                return 1
            }

            menu {
                set cpath [BWidget::clonename $path]
                if { [winfo exists $cpath] } {
                    set path $cpath
                }
                set var [lindex $args 0]
                if { $var != "" } {
                    set _registered($path) [list $var]
                    lappend evt BwHelpMenu
                } else {
                    if {[info exists _registered($path)]} {
                        unset _registered($path)
                    }
                }
                bindtags $path $evt
                return 1
            }

            menuentry {
                set cpath [BWidget::clonename $path]
                if { [winfo exists $cpath] } {
                    set path $cpath
                }
                if { [info exists _registered($path)] } {
                    if { [set index [lindex $args 0]] != "" } {
                        set text  [lindex $args 1]
                        set idx   [lsearch $_registered($path) [list $index *]]
                        if { $text != "" } {
                            if { $idx == -1 } {
                                lappend _registered($path) [list $index $text]
                            } else {
                                set _registered($path) [lreplace $_registered($path) $idx $idx [list $index $text]]
                            }
                        } else {
                            set _registered($path) [lreplace $_registered($path) $idx $idx]
                        }
                    }
                    return 1
                }
                return 0
            }
        }
        if {[info exists _registered($path,balloon)]} {
            unset _registered($path,balloon)
        }
        if {[info exists _registered($path,variable)]} {
            unset _registered($path,variable)
        }
        if {[info exists _registered($path)]} {
            unset _registered($path)
        }
        bindtags $path $evt
        return 1
    } else {
        if {[info exists _registered($path,balloon)]} {
            unset _registered($path,balloon)
        }
	if {[info exists _registered($path,variable)]} {
            unset _registered($path,variable)
        }
        if {[info exists _registered($path)]} {
            unset _registered($path)
        }
        return 0
    }
}


# ------------------------------------------------------------------------------
#  Command DynamicHelp::_motion_balloon
# ------------------------------------------------------------------------------
proc DynamicHelp::_motion_balloon { type path x y } {
    variable _top
    variable _id
    variable _delay
    variable _current_balloon

    if { $_current_balloon != $path && $type == "enter" } {
        set _current_balloon $path
        set type "motion"
        destroy $_top
    }
    if { $_current_balloon == $path } {
        if { $_id != "" } {
            after cancel $_id
            set _id ""
        }
        if { $type == "motion" } {
            if { ![winfo exists $_top] } {
                set _id [after $_delay "DynamicHelp::_show_help $path $x $y"]
            }
        } else {
            destroy $_top
            set _current_balloon ""
        }
    }
}


# ------------------------------------------------------------------------------
#  Command DynamicHelp::_motion_info
# ------------------------------------------------------------------------------
proc DynamicHelp::_motion_info { path } {
    variable _registered
    variable _current_variable
    variable _saved

    if { $_current_variable != $path && [info exists _registered($path,variable)] } {
        if { ![info exists _saved] } {
            set _saved [GlobalVar::getvar [lindex $_registered($path,variable) 0]]
        }
        GlobalVar::setvar [lindex $_registered($path,variable) 0] [lindex $_registered($path,variable) 1]
        set _current_variable $path
    }
}


# ------------------------------------------------------------------------------
#  Command DynamicHelp::_leave_info
# ------------------------------------------------------------------------------
proc DynamicHelp::_leave_info { path } {
    variable _registered
    variable _current_variable
    variable _saved

    if { [info exists _registered($path,variable)] } {
        GlobalVar::setvar [lindex $_registered($path,variable) 0] $_saved
    }
    unset _saved
    set _current_variable ""
    
}


# ------------------------------------------------------------------------------
#  Command DynamicHelp::_menu_info
#    Version of R1v1 restored, due to lack of [winfo ismapped] and <Unmap>
#    under windows for menu.
# ------------------------------------------------------------------------------
proc DynamicHelp::_menu_info { event path } {
    variable _registered
 
    if { [info exists _registered($path)] } {
        set index [$path index active]
        if { [string compare $index "none"] &&
             [set idx [lsearch $_registered($path) [list $index *]]] != -1 } {
            GlobalVar::setvar [lindex $_registered($path) 0] \
                [lindex [lindex $_registered($path) $idx] 1]
        } else {
            GlobalVar::setvar [lindex $_registered($path) 0] ""
        }
    }
}


# ------------------------------------------------------------------------------
#  Command DynamicHelp::_show_help
# ------------------------------------------------------------------------------
proc DynamicHelp::_show_help { path x y } {
    variable _top
    variable _registered
    variable _id
    variable _delay

    if { [Widget::getoption $_top -state] == "disabled" } { return }

    if { [info exists _registered($path,balloon)] } {
        destroy  $_top
        toplevel $_top -relief flat \
            -bg [Widget::getoption $_top -foreground] \
            -bd [Widget::getoption $_top -borderwidth] \
            -screen [winfo screen $path]

        wm overrideredirect $_top 1
        wm transient $_top
        wm withdraw $_top

        label $_top.label -text $_registered($path,balloon) \
            -relief flat -bd 0 -highlightthickness 0 \
            -foreground [Widget::getoption $_top -foreground] \
            -background [Widget::getoption $_top -background] \
            -font       [Widget::getoption $_top -font] \
            -justify    [Widget::getoption $_top -justify]


        pack $_top.label -side left
        update idletasks

	if {![winfo exists $_top]} {return}

        set  scrwidth  [winfo vrootwidth  .]
        set  scrheight [winfo vrootheight .]
        set  width     [winfo reqwidth  $_top]
        set  height    [winfo reqheight $_top]
        incr y 12
        incr x 8

        if { $x+$width > $scrwidth } {
            set x [expr {$scrwidth - $width}]
        }
        if { $y+$height > $scrheight } {
            set y [expr {$y - 12 - $height}]
        }

        wm geometry  $_top "+$x+$y"
        update idletasks

	if {![winfo exists $_top]} {return}
        wm deiconify $_top
    }
}


