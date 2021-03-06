{-# LANGUAGE
    TypeSynonymInstances,
    MultiParamTypeClasses,
    DeriveDataTypeable
    #-}

import Control.Monad
import Codec.Binary.UTF8.String (encodeString)
import Data.Char
import Data.List
import qualified Data.Map as M
import Data.Maybe (isNothing, isJust, catMaybes, fromMaybe)
import Data.Function
import Data.Monoid
import System.Exit
import System.IO
import System.Process
import System.Posix.Process (executeFile)
import System.Posix.Types (ProcessID)
import Text.Printf
--import Text.Regex

import XMonad hiding ((|||))
import qualified XMonad.StackSet as W
import XMonad.Util.ExtensibleState as XS
import XMonad.Util.EZConfig
import XMonad.Util.Loggers
import XMonad.Util.NamedWindows (getName)
import XMonad.Util.NamedScratchpad
import XMonad.Util.Paste
import XMonad.Util.Run
import qualified XMonad.Util.Themes as Theme
import XMonad.Util.Timer
import XMonad.Util.WorkspaceCompare

import XMonad.Prompt
import XMonad.Prompt.Input
import XMonad.Prompt.Man
import XMonad.Prompt.RunOrRaise
import XMonad.Prompt.Shell
import XMonad.Prompt.Window
import XMonad.Prompt.Workspace

import qualified XMonad.Actions.FlexibleManipulate as Flex
import XMonad.Actions.Commands
import XMonad.Actions.CycleRecentWS
import XMonad.Actions.CycleWS
import XMonad.Actions.DynamicWorkspaces
import XMonad.Actions.FloatKeys
import XMonad.Actions.FloatSnap
import XMonad.Actions.GridSelect
import XMonad.Actions.GroupNavigation
import XMonad.Actions.Navigation2D
import qualified XMonad.Actions.Search as S
import XMonad.Actions.Submap
import XMonad.Actions.SpawnOn
import XMonad.Actions.TopicSpace
import XMonad.Actions.UpdatePointer
import XMonad.Actions.Warp
import XMonad.Actions.WindowBringer
import XMonad.Actions.WindowGo
import XMonad.Actions.WindowMenu
import XMonad.Actions.WithAll (sinkAll, killAll)

import XMonad.Hooks.DynamicLog
--import XMonad.Hooks.FadeInactive
{-import XMonad.Hooks.EwmhDesktops hiding (fullscreenEventHook)-}
import EwmhDesktops hiding (fullscreenEventHook)
import XMonad.Hooks.ManageDocks
import XMonad.Hooks.ManageHelpers
import XMonad.Hooks.Place
import XMonad.Hooks.UrgencyHook
import XMonad.Hooks.SetWMName

import XMonad.Layout.PositionStoreFloat
import XMonad.Layout.NoFrillsDecoration
import XMonad.Layout.Accordion
import XMonad.Layout.Drawer
import XMonad.Layout.Combo
import XMonad.Layout.Mosaic
import XMonad.Layout.Fullscreen
import XMonad.Layout.Grid
import XMonad.Layout.LayoutCombinators
import XMonad.Layout.Master
import XMonad.Layout.Maximize
import XMonad.Layout.Minimize
import XMonad.Layout.MouseResizableTile
import XMonad.Layout.MultiToggle
import XMonad.Layout.MultiToggle.Instances
import XMonad.Layout.Named
import XMonad.Layout.NoBorders
import XMonad.Layout.IM
import XMonad.Layout.PerWorkspace
import XMonad.Layout.Reflect
import XMonad.Layout.Renamed
import XMonad.Layout.ResizableTile
import XMonad.Layout.Simplest (Simplest(Simplest))
import XMonad.Layout.SubLayouts
import XMonad.Layout.Tabbed
import XMonad.Layout.TrackFloating
import XMonad.Layout.WindowNavigation
import XMonad.Layout.WorkspaceDir
import XMonad.Layout.WindowSwitcherDecoration

{-
 - TABBED
 -}

myTabTheme =
    defaultTheme
    { activeColor         = "black"
    , inactiveColor       = "black"
    , urgentColor         = "yellow"
    , activeBorderColor   = "orange"
    , inactiveBorderColor = "#333333"
    , urgentBorderColor   = "black"
    , activeTextColor     = "orange"
    , inactiveTextColor   = "#666666"
    , decoHeight          = 24
    , fontName = "xft:Dejavu Sans Mono:size=14"
    }

data TABBED = TABBED deriving (Read, Show, Eq, Typeable)
instance Transformer TABBED Window where
     transform _ x k = k (renamed [Replace "TABBED"] (tabbedAlways shrinkText myTabTheme)) (const x)

{-
 - Navigation2D
 -}

myNavigation2DConfig = defaultNavigation2DConfig { layoutNavigation   = [("Full", centerNavigation)]
                                                 , unmappedWindowRect = [("Full", singleWindowRect)]
                                                 }

myLayout = avoidStruts $
    configurableNavigation (navigateColor "#333333") $
    mkToggle1 TABBED $
    mkToggle1 NBFULL $
    mkToggle1 REFLECTX $
    mkToggle1 REFLECTY $
    mkToggle1 MIRROR $
    mkToggle1 NOBORDERS $
    lessBorders Screen $
    onWorkspace "code" (termDrawer ||| tiled) $
    onWorkspace "im" im $
    onWorkspace "gimp" gimpLayout $
    --fullscreenFull Full ||| termDrawer ||| float ||| tall ||| named "Full|Acc" (Accordion)
    tiled ||| tab ||| full
    where
        tiled = named "Tiled" $ minimize $ addTabs shrinkText myTabTheme $ subLayout [] Simplest $ ResizableTall 1 0.03 0.5 []
        full = named "Full" $ minimize $ fullscreenFull Full
        tab = named "Tab" $ minimize $ tabbedBottom shrinkText myTabTheme *||* tiled
        --im = named "IM" $ minimize $ withIM (360/1920) (Title "QQ Lite") $ reflectHoriz $ withIM (300/1920) (Title "Hangouts") tiled
        im = named "IM" $ minimize $ gridIM (360/1920) (Title "QQ Lite")
        {-gimpLayout = named "Gimp" $ withIM (0.130) (Role "gimp-toolbox") $ reflectHoriz $ withIM (0.2) (Role "gimp-dock") (trackFloating simpleTabbed)-}
        gimpLayout = named "Gimp" $ withIM (0.130) (Role "gimp-toolbox") $ (simpleDrawer 0.2 0.2 (Role "gimp-dock") `onRight` Full)
        termDrawer = named "TermDrawer" $ simpleDrawer 0.0 0.4 (ClassName "URxvt") `onBottom` Full
        --float = noFrillsDeco shrinkText defaultTheme positionStoreFloat
        myTab = defaultTheme
                { activeColor         = "black"
                , inactiveColor       = "black"
                , urgentColor         = "yellow"
                , activeBorderColor   = "orange"
                , inactiveBorderColor = "#333333"
                , urgentBorderColor   = "black"
                , activeTextColor     = "orange"
                , inactiveTextColor   = "#666666"
                , decoHeight          = 18
                }

doSPFloat = customFloating $ W.RationalRect (1/6) (1/6) (4/6) (4/6)
myManageHook = composeAll $
    [ className =? c --> viewShift "web" | c <- ["Firefox"] ] ++
    [ className =? c <&&> role =? "browser" --> viewShift "web" | c <- ["Google-chrome-stable", "Google-chrome-beta", "Chromium"] ] ++
    [ className =? c --> viewShift "code" | c <- ["Gvim"] ] ++
    [ className =? c --> viewShift "doc" | c <- ["Okular", "MuPDF", "llpp", "Recoll", "Evince", "Zathura" ] ] ++
    [ appName =? c --> viewShift "doc" | c <- ["calibre-ebook-viewer", "calibre-edit-book"] ] ++
    [ appName =? c --> viewShift "office" | c <- ["idaq.exe", "idaq64.exe"] ] ++
    [ className =? c --> viewShift "office" | c <- ["Idaq", "Inkscape", "Geeqie", "Wps", "Wpp"] ] ++
    [ role =? r --> doShift "im" | r <- ["pop-up", "app"]] ++ -- viewShift doesn't work
    {-[ className =? "Google-chrome-stable" <&&> role =? r --> doShift "im" | r <- ["pop-up", "app"]] ++ -- viewShift doesn't work-}
    [ title =? "weechat" --> viewShift "im"] ++
    [ title =? "newsbeuter" --> viewShift "news"] ++
    [ title =? "mutt" --> viewShift "mail"] ++
    [ className =? c --> viewShift "gimp" | c <- ["Gimp"] ] ++
    [ prefixTitle "emacs" --> doShift "emacs" ] ++
    [ className =? c --> doShift "misc" | c <- ["Wpa_gui"] ] ++
    [ prefixTitle "libreoffice" <||> prefixTitle "LibreOffice" --> doShift "office" ] ++
    [ className =? "Do" --> doIgnore ] ++
    [ manageDocks , namedScratchpadManageHook scratchpads ] ++
    [ className =? c --> ask >>= \w -> liftX (hide w) >> idHook | c <- ["XClipboard"] ] ++
    [ mySPFloats --> doSPFloat ] ++
    [ myCenterFloats --> doCenterFloat ]
  where
    role = stringProperty "WM_WINDOW_ROLE"
    prefixTitle prefix = fmap (prefix `isPrefixOf`) title
    viewShift = doF . liftM2 (.) W.greedyView W.shift
    myCenterFloats = foldr1 (<||>)
        [ className =? "feh"
        , className =? "Display"
        ]
    mySPFloats = foldr1 (<||>)
        [ className =? "Firefox" <&&> fmap (/="Navigator") appName
        , className =? "Nautilus" <&&> fmap (not . isSuffixOf " - File Browser") title
        , className =? "SDL_App"
        , className =? "Gimp" <&&> fmap (not . flip any ["image-window", "toolbox", "dock"] . flip isSuffixOf) role
        , fmap (=="GtkFileChooserDialog") role
        {-, fmap (/= "Google-chrome-stable") className <&&> role =? "pop-up"-}
        , fmap (isPrefixOf "sun-") appName
        , fmap (isPrefixOf "Gnuplot") title
        , flip fmap className $ flip elem
            [ "XClock"
            , "Xmessage"
            , "Floating"
            ]
        ]

{-
myDynamicLog h = dynamicLogWithPP $ defaultPP
  { ppCurrent = ap clickable (wrap "^i(/home/ray/.xmonad/icons/default/" ")" . fromMaybe "application-default-icon.xpm" . flip M.lookup myIcons)
  , ppVisible = ap clickable (wrap "^i(/home/ray/.xmonad/icons/default/" ")" . fromMaybe "application-default-icon.xpm" . flip M.lookup myIcons)
  , ppHidden = ap clickable (wrap "^i(/home/ray/.xmonad/icons/gray/" ")" . fromMaybe "application-default-icon.xpm" . flip M.lookup myIcons)
  , ppUrgent = ap clickable (wrap "^i(/home/ray/.xmonad/icons/highlight/" ")" . fromMaybe "application-default-icon.xpm" . flip M.lookup myIcons)
  , ppSep = dzenColor "#0033FF" "" " | "
  , ppWsSep = ""
  , ppTitle  = dzenColor "green" "" . shorten 45
  , ppLayout = id
  , ppOrder  = \(ws:l:t:exs) -> [t,l,ws]++exs
  , ppSort   = fmap (namedScratchpadFilterOutWorkspace.) (ppSort byorgeyPP)
  , ppExtras = [ dzenColorL "violet" "" $ date "%R %a %y-%m-%d"
               , dzenColorL "orange" "" battery
               ]
  , ppOutput = hPutStrLn h
  }
  where
    clickable w = wrap ("^ca(1,wmctrl -s `wmctrl -d | grep "++w++" | cut -d' ' -f1`)") "^ca()"
-}

myDynamicLog h = dynamicLogWithPP $ xmobarPP
  { ppOutput  = hPutStrLn h
  , ppCurrent = wrap "<icon=default/" "/>" . fromMaybe "application-default-icon.xpm" . flip M.lookup myIcons
  , ppVisible = wrap "<icon=default/" "/>" . fromMaybe "application-default-icon.xpm" . flip M.lookup myIcons
  , ppHidden = wrap "<icon=gray/" "/>" . fromMaybe "application-default-icon.xpm" . flip M.lookup myIcons
  , ppUrgent = wrap "<icon=highlight/" "/>" . fromMaybe "application-default-icon.xpm" . flip M.lookup myIcons
  , ppSort    = (. namedScratchpadFilterOutWorkspace) <$> ppSort defaultPP
  , ppTitle   = (" " ++) . xmobarColor "#ee9a00" ""
  }
  where
    clickable w = wrap ("^ca(1,wmctrl -s `wmctrl -d | grep "++w++" | cut -d' ' -f1`)") "^ca()"

{-
 - Bindings
 -}

myMouseBindings (XConfig {XMonad.modMask = modm}) = M.fromList $
    [ ((modm, button1), (\w -> focus w >> Flex.mouseWindow Flex.position w))
    , ((modm, button2), (\w -> focus w >> Flex.mouseWindow Flex.linear w))
    , ((modm, button3), (\w -> focus w >> Flex.mouseWindow Flex.resize w))
    ]

myKeys =
    [ ("M-" ++ m ++ [k], f i)
        | (i, k) <- zip myTopicNames "1234567890-="
        , (f, m) <- [ (switchTopic myTopicConfig, "")
                    , (windows . liftM2 (.) W.view W.shift, "S-")
                    ]
    ]
    ++
    [ ("C-; " ++ m ++ [k], f i)
        | (i, k) <- zip myTopicNames "asdfghjkl;'\""
        , (f, m) <- [ (switchTopic myTopicConfig, "")
                    , (windows . W.shift, "S-")
                    ]
    ]
    ++
    [("M-" ++ m ++ k, screenWorkspace sc >>= flip whenJust (windows . f))
        | (k, sc) <- zip ["w", "e", "r"] [0..]
        , (f, m) <- [(W.view, ""), (liftM2 (.) W.view W.shift, "S-")]
    ]
    ++
    [ ("M-S-q", io exitFailure)
    , ("M-S-c", kill)
    , ("M-q", spawn "ghc -e ':m +XMonad Control.Monad System.Exit' -e 'flip unless exitFailure =<< recompile False' && xmonad --restart")

    , ("<Print>", spawn "import /tmp/screen.jpg")
    , ("C-<Print>", spawn "import -window root /tmp/screen.jpg")
    , ("M-<Return>", spawn "urxvt" >> sendMessage (JumpToLayout "ResizableTall"))
    , ("M-g", spawnSelected defaultGSConfig ["zsh -c 'xdg-open /tmp/*(on[1])'", "urxvtd -q -f -o", urxvt "weechat", "xterm", "gimp", "inkscape", "audacity", "wireshark", "ida", "ida64", "winecfg"])
    , ("M-S-i", spawn "pkill compton; compton --glx-no-stencil --invert-color-include 'g:e:Firefox' --invert-color-include 'g:e:Google-chrome-stable' --invert-color-include 'g:e:Google-chrome-beta' --invert-color-include 'g:e:Chromium' --invert-color-include 'g:e:Wps' --invert-color-include 'g:e:Wpp' --invert-color-include 'g:e:libreoffice-writer' --invert-color-include 'g:e:Goldendict' --invert-color-include 'g:e:com-mathworks-util-PostVMInit' &")
    , ("M-C-i", spawn "pkill compton; compton &")
    , ("M-S-l", spawn "xscreensaver-command -lock")
    , ("M-S-k", spawn "xkill")
    , ("<XF86AudioNext>", spawn "mpc_seek forward")
    , ("<XF86AudioPrev>", spawn "mpc_seek backward")
    , ("<XF86AudioRaiseVolume>", spawn "change_volume up")
    , ("<XF86AudioLowerVolume>", spawn "change_volume down")
    , ("<XF86AudioMute>", spawn "amixer set Master mute")
    , ("<XF86AudioPlay>", spawn "mpc toggle")
    , ("<XF86Eject>", spawn "eject")
    , ("M-S-a", sendMessage Taller)
    , ("M-S-z", sendMessage Wider)
    , ("M-S-f", placeFocused $ withGaps (22, 0, 0, 0) $ smart (0.5,0.5))
    , ("M-v", spawn $ "sleep .2 ; xdotool type --delay 0 --clearmodifiers \"$(xclip -o)\"")

    -- window management
    , ("M-<Tab>", cycleRecentWS [xK_Super_L] xK_Tab xK_Tab)
    , ("M-a", toggleSkip ["NSP"])
    , ("M-N", doTo Prev EmptyWS getSortByIndex (windows . liftM2 (.) W.view W.shift))
    , ("M-n", doTo Next EmptyWS getSortByIndex (windows . liftM2 (.) W.view W.shift))
    , ("M-<Space>", sendMessage NextLayout)
    , ("M-i", sendMessage Shrink)
    , ("M-o", sendMessage Expand)
    , ("M-t", withFocused $ windows . W.sink)
    , ("M-,", sendMessage (IncMasterN 1))
    , ("M-.", sendMessage (IncMasterN (-1)))
    , ("M-b", windowPromptBring myXPConfig)
    , ("M-S-b", banishScreen LowerRight)
    , ("M-s", windows W.swapMaster)
    , ("M-<Backspace>", focusUrgent)
    , ("M-y", nextMatch History (return True))
    , ("M-;", switchLayer)
    , ("M-m", withFocused minimizeWindow)
    , ("M-S-m", sendMessage RestoreNextMinimizedWin)
    , ("M-f", toggleFF)

    -- XMonad.Layout.SubLayouts {{{
    , ("M-C-h", sendMessage $ pullGroup L)
    , ("M-C-j", sendMessage $ pullGroup D)
    , ("M-C-k", sendMessage $ pullGroup U)
    , ("M-C-l", sendMessage $ pullGroup R)
    , ("M-C-m", withFocused (sendMessage . MergeAll))
    , ("M-C-u", withFocused (sendMessage . UnMerge))
    -- }}}

    {-, ("M-h", windowGo L True)-}
    {-, ("M-j", windowGo D True)-}
    {-, ("M-k", windowGo U True)-}
    {-, ("M-l", windowGo R True)-}
    , ("M-j", windows W.focusDown)
    , ("M-k", windows W.focusUp)
    , ("M-S-<L>", withFocused (keysResizeWindow (-30,0) (0,0))) --shrink float at right
    , ("M-S-<R>", withFocused (keysResizeWindow (30,0) (0,0))) --expand float at right
    , ("M-S-<D>", withFocused (keysResizeWindow (0,30) (0,0))) --expand float at bottom
    , ("M-S-<U>", withFocused (keysResizeWindow (0,-30) (0,0))) --shrink float at bottom
    , ("M-C-<L>", withFocused (keysResizeWindow (30,0) (1,0))) --expand float at left
    , ("M-C-<R>", withFocused (keysResizeWindow (-30,0) (1,0))) --shrink float at left
    , ("M-C-<U>", withFocused (keysResizeWindow (0,30) (0,1))) --expand float at top
    , ("M-C-<D>", withFocused (keysResizeWindow (0,-30) (0,1))) --shrink float at top
    , ("M-<L>", withFocused (keysMoveWindow (-30,0)))
    , ("M-<R>", withFocused (keysMoveWindow (30,0)))
    , ("M-<U>", withFocused (keysMoveWindow (0,-30)))
    , ("M-<D>", withFocused (keysMoveWindow (0,30)))
    , ("C-; <L>", withFocused $ snapMove L Nothing)
    , ("C-; <R>", withFocused $ snapMove R Nothing)
    , ("C-; <U>", withFocused $ snapMove U Nothing)
    , ("C-; <D>", withFocused $ snapMove D Nothing)

    -- dynamic workspace
    , ("M-C-n", addWorkspacePrompt myXPConfig)
    , ("M-C-r", removeWorkspace)
    , ("M-C-S-r", killAll >> removeWorkspace)

    -- backlight
    , ("M-<F1>", spawnSelected defaultGSConfig [ "xbacklight =30"
                                               , "xbacklight =40"
                                               , "xbacklight =20"
                                               , "xbacklight =10"
                                               , "xbacklight =15"
                                               , "xbacklight =25"
                                               , "xbacklight =5"
                                               ])

    -- Volume
    , ("C-; 9", spawn "change_volume down")
    , ("C-; 0", spawn "change_volume up")
    , ("C-; m", spawn "change_volume toggle")

    -- preferred cui programs
    , ("C-; C-;", pasteChar controlMask ';')
    , ("C-' C-'", pasteChar controlMask '\'')
    , ("C-' g", namedScratchpadAction scratchpads "ghci")
    , ("C-' l", namedScratchpadAction scratchpads "livescript")

    , ("C-' a", namedScratchpadAction scratchpads "alsamixer")
    , ("C-' c", namedScratchpadAction scratchpads "cmus")
    , ("C-' d", namedScratchpadAction scratchpads "goldendict")
    , ("C-' e", namedScratchpadAction scratchpads "erl")
    , ("C-' f", namedScratchpadAction scratchpads "coffee")
    , ("C-' h", namedScratchpadAction scratchpads "htop")
    , ("C-' j", namedScratchpadAction scratchpads "jc")
    , ("C-' m", namedScratchpadAction scratchpads "ncmpcpp")
    , ("C-' o", namedScratchpadAction scratchpads "utop")
    , ("C-' i", namedScratchpadAction scratchpads "rawutop")
    , ("C-' p", namedScratchpadAction scratchpads "ipython")
    , ("C-' q", namedScratchpadAction scratchpads "swipl")
    , ("C-' r", namedScratchpadAction scratchpads "pry")
    , ("C-' t", namedScratchpadAction scratchpads "task")
    , ("C-' u", namedScratchpadAction scratchpads "R")
    , ("C-' k", namedScratchpadAction scratchpads "pure")
    , ("C-' z", namedScratchpadAction scratchpads "zeal")

    , ("M-C-<Space>", sendMessage $ Toggle NBFULL)
    , ("M-C-t", sendMessage $ Toggle TABBED)
    , ("M-C-x", sendMessage $ Toggle REFLECTX)
    , ("M-C-y", sendMessage $ Toggle REFLECTY)
    , ("M-C-z", sendMessage $ Toggle MIRROR)
    , ("M-C-b", sendMessage $ Toggle NOBORDERS)

    -- prompts
    , ("M-'", workspacePrompt myXPConfig (switchTopic myTopicConfig) )
    , ("M-p c", mainCommandPrompt myXPConfig)
    , ("M-p d", changeDir myXPConfig)
    --, ("M-p f", fadePrompt myXPConfig)
    --, ("M-p m", manPrompt myXPConfig)
    , ("M-p p", spawn "launcher")
    , ("M-p e", launchApp myXPConfig "evince" ["pdf","ps"])
    , ("M-p F", launchApp myXPConfig "feh" ["png","jpg","gif"])
    , ("M-p l", launchApp myXPConfig "llpp" ["pdf","ps"])
    , ("M-p m", spawn "menu")
    , ("M-p z", launchApp myXPConfig "zathura" ["pdf","ps"])
    , ("M-p M-p", runOrRaisePrompt myXPConfig)
    ] ++
    searchBindings

-- Toggle workspaces but ignore some
toggleSkip :: [WorkspaceId] -> X ()
toggleSkip skips = do
    hs <- XMonad.gets (flip skipTags skips . W.hidden . windowset)
    unless (null hs) (windows . W.view . W.tag $ head hs)

urxvt prog = ("urxvt -T "++) . ((++) . head $ words prog) . (" -e "++) . (prog++) $ ""
scratchpads =
  map f ["cmus", "erl", "ghci", "gst", "node", "swipl", "coffee", "ipython", "livescript", "pry", "R", "alsamixer", "htop", "xosview", "ncmpcpp", "utop"] ++
  [ NS "rawutop" "urxvt -T rawutop -e utop -init /dev/null" (title =? "rawutop") doSPFloat
  , NS "task" "urxvt -T task -e tasksh" (title =? "task") doSPFloat
  , NS "jc" "urxvt -T jc -e ~/.local/opt/j64-803/jconsole.sh" (title =? "jc") doSPFloat
  , NS "agenda" "org-agenda" (title =? "Agenda Frame") orgFloat
  , NS "capture" "org-capture" (title =? "Capture Frame") orgFloat
  , NS "eix-sync" "urxvt -T eix-sync -e sh -c \"sudo eix-sync; read\"" (title =? "eix-sync") doTopFloat
  , NS "getmail" "urxvt -T getmail -e getmail -r rc0 -r rc1" (title =? "getmail") doTopRightFloat
  , NS "goldendict" "goldendict" (className =? "Goldendict") doSPFloat
  , NS "zeal" "zeal" (className =? "Zeal") doSPFloat
  ]
  where
    f s = NS s (urxvt s) (title =? s) doSPFloat
    doTopFloat = customFloating $ W.RationalRect (1/3) 0 (1/3) (1/3)
    doTopLeftFloat = customFloating $ W.RationalRect 0 0 (1/3) (1/3)
    doTopRightFloat = customFloating $ W.RationalRect (2/3) 0 (1/3) (1/3)
    doBottomLeftFloat = customFloating $ W.RationalRect 0 (2/3) (1/3) (1/3)
    doBottomRightFloat = customFloating $ W.RationalRect (2/3) (2/3) (1/3) (1/3)
    doLeftFloat = customFloating $ W.RationalRect 0 0 (1/3) 1
    orgFloat = customFloating $ W.RationalRect (1/2) (1/2) (1/2) (1/2)

{-myConfig dzen = withNavigation2DConfig myNavigation2DConfig $ withUrgencyHook NoUrgencyHook $ defaultConfig-}
myConfig xmobar = ewmh $ withUrgencyHook NoUrgencyHook $ defaultConfig
    { terminal           = "urxvt"
    , focusFollowsMouse  = False -- see: focusFollow
    , borderWidth        = 1
    , modMask            = mod4Mask
    , workspaces         = myTopicNames
    , normalBorderColor  = "#000000"
    , focusedBorderColor = "#3939ff"
    , mouseBindings      = myMouseBindings
    , layoutHook         = myLayout
    , manageHook         = myManageHook
    , handleEventHook    = fullscreenEventHook <+> focusFollow -- >> clockEventHook
    , logHook            = historyHook >> myDynamicLog xmobar
    , startupHook        = checkKeymap (myConfig xmobar) myKeys >> spawn "~/bin/start-tiling" >> setWMName "LG3D" >> clockStartupHook
} `additionalKeysP` myKeys

-- {{{ Toggle follow Mouse
-- from: http://www.haskell.org/haskellwiki/Xmonad/Config_archive/adamvo's_xmonad.hs
-- A nice little example of extensiblestate
newtype FocusFollow = FocusFollow {getFocusFollow :: Bool } deriving (Typeable,Read,Show)
instance ExtensionClass FocusFollow where
    initialValue = FocusFollow True
    extensionType = PersistentExtension

-- this eventHook is the same as from xmonad for handling crossing events
focusFollow e@(CrossingEvent {ev_window=w, ev_event_type=t})
        | t == enterNotify, ev_mode e == notifyNormal =
    whenX (XS.gets getFocusFollow) (focus w) >> return (All True)
focusFollow _ = return (All True)

toggleFF = XS.modify $ FocusFollow . not . getFocusFollow
--}}}

{-
defaultFade = 8/10
data FadeState = FadeState Rational (M.Map Window Rational) deriving (Typeable,Read,Show)
instance ExtensionClass FadeState where
  initialValue = FadeState defaultFade M.empty
  extensionType = PersistentExtension

myFadeHook :: Query Rational
myFadeHook = do
  w <- ask
  FadeState fadeUnfocused fadeSet <- liftX XS.get
  case M.lookup w fadeSet of
    Just v -> return v
    Nothing -> do
      b <- isUnfocused
      return $ if b then fadeUnfocused else 1
-}

myPromptKeymap = M.union defaultXPKeymap $ M.fromList
                 [
                   ((controlMask, xK_g), quit)
                 , ((controlMask, xK_m), setSuccess True >> setDone True)
                 , ((controlMask, xK_j), setSuccess True >> setDone True)
                 , ((controlMask, xK_h), deleteString Prev)
                 , ((controlMask, xK_f), moveCursor Next)
                 , ((controlMask, xK_b), moveCursor Prev)
                 , ((controlMask, xK_p), moveHistory W.focusDown')
                 , ((controlMask, xK_n), moveHistory W.focusUp')
                 , ((mod1Mask, xK_p), moveHistory W.focusDown')
                 , ((mod1Mask, xK_n), moveHistory W.focusUp')
                 , ((mod1Mask, xK_b), moveWord Prev)
                 , ((mod1Mask, xK_f), moveWord Next)
                 ]

myXPConfig = defaultXPConfig
    { font = "xft:DejaVu Sans Mono:pixelsize=16"
    , bgColor           = "#0c1021"
    , fgColor           = "#f8f8f8"
    , fgHLight          = "#f8f8f8"
    , bgHLight          = "steelblue3"
    , borderColor       = "DarkOrange"
    , promptBorderWidth = 1
    , position          = Top
    , historyFilter     = deleteConsecutive
    , promptKeymap = myPromptKeymap
    }

-- | Like 'spawn', but uses bash and returns the 'ProcessID' of the launched application
spawnBash :: MonadIO m => String -> m ProcessID
spawnBash x = xfork $ executeFile "/bin/bash" False ["-c", encodeString x] Nothing

main = do
    checkTopicConfig myTopicNames myTopicConfig
    d <- openDisplay ""
    let w = fromIntegral $ displayWidth d 0 :: Int
        h = fromIntegral $ displayHeight d 0 :: Int
    let barWidth = 160 --h `div` 12
    let barHeight = h `div` 35
    let fontSize = h `div` 54
    {-dzen <- spawnPipe $ "killall dzen2; dzen2 -x " ++ (show $ barWidth*6) ++ " -h " ++ show barHeight ++ " -ta right -fg '#a8a3f7' -fn 'WenQuanYi Micro Hei-" ++ show fontSize ++ "'"-}
    xmobar <- spawnPipe "killall xmobar; xmobar"
    -- remind <http://www.roaringpenguin.com/products/remind>
    -- dzenRem <- spawnBash $ "rem | tail -n +3 | grep . | { read a; while read t; do b[${#b[@]}]=$t; echo $t; done; { echo $a; for a in \"${b[@]}\"; do echo $a; done; } | dzen2 -p -x " ++ show barWidth ++ " -w " ++ (show $ barWidth*4) ++ " -h " ++ show barHeight ++ " -ta l -fg '#a8a3f7' -fn 'WenQuanYi Micro Hei-" ++ show fontSize ++ "' -l ${#b[@]}; }"
    spawn $ "killall trayer; trayer --align left --edge top --expand false --width " ++ show barWidth ++ " --transparent true --tint 0x000000 --widthtype pixel --SetPartialStrut true --SetDockType true --height " ++ show barHeight
    xmonad $ myConfig xmobar

{-
 - SearchMap
 -}

searchBindings = [ ("M-S-/", S.promptSearch myXPConfig multi) ] ++
                 [ ("M-/ " ++ name, S.promptSearch myXPConfig e) | e@(S.SearchEngine name _) <- engines, length name == 1 ]
  where
    promptSearch (S.SearchEngine _ site)
      = inputPrompt myXPConfig "Search" ?+ \s ->
      (S.search "chrome" site s >> viewWeb)
    viewWeb = windows (W.view "web")

    mk = S.searchEngine
    engines = [ mk "h" "http://www.haskell.org/hoogle/?q="
      , mk "g" "http://www.google.com/search?num=100&q="
      , mk "t" "http://developer.gnome.org/search?q="
      , mk "w" "http://en.wikipedia.org/wiki/Special:Search?go=Go&search="
      , mk "d" "http://duckduckgo.com/?q="
      , mk "m" "https://developer.mozilla.org/en-US/search?q="
      , mk "e" "http://erldocs.com/R15B/mnesia/mnesia.html?search="
      , mk "r" "http://www.ruby-doc.org/search.html?sa=Search&q="
      , mk "p" "http://docs.python.org/search.html?check_keywords=yes&area=default&q="
      , mk "s" "https://scholar.google.de/scholar?q="
      , mk "i" "https://ixquick.com/do/search?q="
      , mk "gt" "https://bugs.gentoo.org/buglist.cgi?quicksearch="
      , mk "dict" "http://www.dict.cc/?s="
      , mk "imdb" "http://www.imdb.com/find?s=all&q="
      , mk "def" "http://www.google.com/search?q=define:"
      , mk "img" "http://images.google.com/images?q="
      , mk "gh" "https://github.com/search?q="
      , mk "bb" "https://bitbucket.org/repo/all?name="
      , mk "alpha" "http://www.wolframalpha.com/input/i="
      , mk "ud" "http://www.urbandictionary.com/define.php?term="
      , mk "rtd" "http://readthedocs.org/search/project/?q="
      , mk "null" "http://nullege.com/codes/search/"
      , mk "sf" "http://sourceforge.net/search/?q="
      , mk "acm" "https://dl.acm.org/results.cfm?query="
      , mk "math" "http://mathworld.wolfram.com/search/?query="
      ]
    multi = S.namedEngine "multi" $ foldr1 (S.!>) engines

{-
 - Topic
 -}

data TopicItem = TI { topicName :: Topic
                    , topicDir  :: Dir
                    , topicAction :: X ()
                    , topicIcon :: FilePath
                    }

myTopicNames :: [Topic]
myTopicNames = map topicName myTopics

myTopicConfig :: TopicConfig
myTopicConfig = TopicConfig
    { topicDirs = M.fromList $ map (\(TI n d _ _) -> (n,d)) myTopics
    , defaultTopicAction = const (return ())
    , defaultTopic = "web"
    , maxTopicHistory = 10
    , topicActions = M.fromList $ map (\(TI n _ a _) -> (n,a)) myTopics
    }

myIcons = M.fromList $ map (\(TI n _ _ i) -> (n,i)) myTopics

myTopics :: [TopicItem]
myTopics =
    [ TI "web" "" (spawn "firefox") "chrome.xpm"
    , TI "code" "" (spawn "/usr/bin/gvim") "gvim.xpm"
    , TI "term" "" (urxvt "tmux attach -t default") "xterm.xpm"
    , TI "doc" "Documents/" (return ()) "evince.xpm"
    , TI "office" "Documents/" (return ()) "libreoffice34-base.xpm"
    , TI "im" "" (urxvt "weechat") "weechat.xpm"
    , TI "news" "" (urxvt "newsbeuter") "newsbeuter.xpm"
    , TI "mail" "" (urxvt "mutt" >> spawn "killall -WINCH mutt") "mutt.xpm"
    , TI "gimp" "" (return ()) "gimp.xpm"
    , TI "emacs" "" (spawn "emacsclient -c -n") "emacs.xpm"
    , TI "misc" "" (return ()) "gtk-network.xpm"
    ]
  where
    urxvt prog = spawn . ("urxvt -T "++) . ((++) . head $ words prog) . (" -e "++) . (prog++) $ ""


myCommands =
    [ ("getmail", namedScratchpadAction scratchpads "getmail")
    , ("wallpaper", safeSpawn "change-wallpaper" [])
    --, ("fade", fadePrompt myXPConfig)
    ]

{-
fadePrompt xpc = withFocused $ \w -> do
  mkXPrompt (TitledPrompt "fade to") xpc (\s -> return [show x | x <- [0..10], s `isPrefixOf` show x]) $ \i -> do
    let v = read i :: Int
    FadeState u s <- XS.get
    XS.put . FadeState u $ if all isDigit i && 0 <= v && v <= 10
      then M.insert w (toRational v/10) s
      else M.delete w s
-}


data TitledPrompt = TitledPrompt String

instance XPrompt TitledPrompt where
    showXPrompt (TitledPrompt t)  = t ++ ": "
    commandToComplete _ c   = c
    nextCompletion    _     = getNextCompletion

mkCommandPrompt :: XPConfig -> [(String, X ())] -> X ()
mkCommandPrompt xpc cs = do
    mkXPrompt (TitledPrompt "Command") xpc compl $ \i -> whenJust (find ((==i) . fst) cs) snd
  where
    compl s = return . filter (searchPredicate xpc s) . map fst $ cs

mainCommandPrompt xpc = do
  defs <- defaultCommands
  mkCommandPrompt xpc $ nubBy ((==) `on` fst) $ myCommands ++ defs

getFilesWithExt :: [String] -> String -> IO [String]
getFilesWithExt exts s = fmap lines $ runProcessWithInput "sh" [] ("ls -d -- " ++ s ++ "*/ " ++ s ++ "*." ++ f ++ "\n")
  where
    f = if length exts == 1 then head exts else ('{':) . (++"}") $ intercalate "," exts

{- | Get the user's response to a prompt an launch an application using the
   input as command parameters of the application.-}
launchApp :: XPConfig -> String -> [String] -> X ()
launchApp config app exts = mkXPrompt (TitledPrompt app) config (getFilesWithExt exts) $ launch app
  where
    launch :: MonadIO m => String -> String -> m ()
    launch app params = spawn $ app ++ " " ++ completionToCommand (undefined :: Shell) params


data TidState = TID TimerId deriving Typeable

instance ExtensionClass TidState where
  initialValue = TID 0

clockStartupHook = startTimer 1 >>= XS.put . TID

clockEventHook e = do
  (TID t) <- XS.get
  handleTimer t e $ do
    startTimer 1 >>= XS.put . TID
    ask >>= logHook.config
    return Nothing
  return $ All True
