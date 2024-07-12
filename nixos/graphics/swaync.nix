{pkgs, config, lib, inputs, ... }: let cfg = config.tp.graphics; in {
  options.tp.graphics = {
    swaync = lib.mkEnableOption "Enable swaync and theming for it";
  };

  config = lib.mkIf cfg.swaync {
    tp.hm.home.file.".config/swaync/config.json".text = ''
      {
        "$schema": "/etc/xdg/swaync/configSchema.json",
        "positionX": "right",
        "positionY": "top",
        "layer": "top",
        "cssPriority": "application",
        "control-center-margin-top": 0,
        "control-center-margin-bottom": 0,
        "control-center-margin-right": 0,
        "control-center-margin-left": 0,
        "notification-icon-size": 64,
        "notification-body-image-height": 150,
        "notification-body-image-width": 200,
        "timeout": 10,
        "timeout-low": 5,
        "timeout-critical": 0,
        "fit-to-screen": true,
        "control-center-width": 500,
        "control-center-height": 600,
        "notification-window-width": 500,
        "keyboard-shortcuts": true,
        "image-visibility": "when-available",
        "transition-time": 200,
        "hide-on-clear": false,
        "hide-on-action": true,
        "script-fail-notify": true,
        "scripts": {
            "example-script": {
            "exec": "echo 'Do something...'",
            "urgency": "Normal"
            },
            "example-action-script": {
            "exec": "echo 'Do something actionable!'",
            "urgency": "Normal",
            "run-on": "action"
            }
        },
        "notification-visibility": {
            "example-name": {
            "state": "muted",
            "urgency": "Low",
            "app-name": "Spotify"
            }
        },
        "widgets": [
            "inhibitors",
            "title",
            "dnd",
            "notifications"
        ],
        "widget-config": {
            "inhibitors": {
            "text": "Inhibitors",
            "button-text": "Clear All",
            "clear-all-button": true
            },
            "title": {
            "text": "Notifications",
            "clear-all-button": true,
            "button-text": "Clear All"
            },
            "dnd": {
            "text": "Do Not Disturb"
            },
            "label": {
            "max-lines": 5,
            "text": "Label Text"
            },
            "mpris": {
            "image-size": 96,
            "image-radius": 12
            }
        }
      }
    '';
    tp.hm.home.file.".config/swaync/style.css".text = ''
        /*
        * vim: ft=less
        */

        @define-color cc-bg #1e1e2e;

        @define-color mpris-bg rgb(30, 32, 48);
        
        @define-color noti-border-color #a6e3a1;
        @define-color noti-bg #1e1e2e;
        @define-color noti-bg-hover #313244;
        @define-color noti-bg-focus #1e1e2e;
        @define-color noti-close-bg #1e1e2e;
        @define-color noti-close-bg-hover #1e1e2e;
        @define-color text #a6e3a1;
        
        @define-color bg-selected rgb(138, 173, 244);
        @define-color scale-trough rgb(244, 219, 214);
        
        * {
        color: @text;
        }
        
        .notification-row {
        background: none;
        box-shadow: none;
        }
        
        .notification {
        border-radius: 10px;
        margin: 12px 12px;
        box-shadow: none;
        padding: 0;
        }
        
        scale {
        padding-left: 21px;
        padding-right: 18px;
        }
        
        scale trough {
        background-color: @scale-trough;
        }
        
        scale trough highlight {
        background-color: @bg-selected;
        background-image: none;
        }
        
        scale trough slider {
        background-color: @bg-selected;
        border: 2px solid @bg-selected;
        box-shadow: none;
        }
        
        /* Uncomment to enable specific urgency colors
        .low {
        background: yellow;
        padding: 12px;
        border-radius: 10px;
        }
        
        .normal {
        background: green;
        padding: 12px;
        border-radius: 10px;
        }
        
        .critical {
        background: red;
        padding: 12px;
        border-radius: 10px;
        }
        */
        
        .notification-content {
        background: none;
        padding: 12px;
        border-radius: 10px;
        }
        
        .close-button {
        background: @noti-close-bg;
        color: @text;
        text-shadow: none;
        padding: 0;
        border-radius: 100%;
        margin-top: 16px;
        margin-right: 16px;
        box-shadow: none;
        border: none;
        min-width: 24px;
        min-height: 24px;
        }
        
        .close-button:hover {
        box-shadow: none;
        background: @noti-close-bg-hover;
        transition: all 0.15s ease-in-out;
        border: none;
        }
        
        .notification-default-action,
        .notification-action {
        padding: 12px;
        margin: 0;
        box-shadow: none;
        background: @noti-bg;
        border: 1px solid @noti-border-color;
        color: @text;
        }
        
        .notification-default-action:hover,
        .notification-action:hover {
        -gtk-icon-effect: none;
        background: @noti-bg-hover;
        }
        
        .notification-default-action:active,
        .notification-action:active {
        background: @noti-bg;
        }
        
        .notification-default-action {
        border-radius: 10px;
        }
        
        /* When alternative actions are visible */
        .notification-default-action:not(:only-child) {
        border-bottom-left-radius: 0px;
        border-bottom-right-radius: 0px;
        }
        
        .notification-action {
        border-radius: 0px;
        border-top: none;
        border-right: none;
        }
        
        /* add bottom border radius to eliminate clipping */
        .notification-action:first-child {
        border-bottom-left-radius: 10px;
        }
        
        .notification-action:last-child {
        border-bottom-right-radius: 10px;
        border-right: 1px solid @noti-border-color;
        }
        
        .body-image {
        margin-top: 6px;
        background-color: @text;
        border-radius: 15px;
        }
        
        .summary {
        font-size: 16px;
        font-weight: bold;
        background: none;
        color: @text;
        text-shadow: none;
        }
        
        .time {
        font-size: 16px;
        font-weight: bold;
        background: none;
        color: @text;
        text-shadow: none;
        margin-right: 18px;
        }
        
        .body {
        font-size: 15px;
        font-weight: normal;
        color: @text;
        text-shadow: none;
        }
        
        .control-center {
        background: @cc-bg;
        border-radius: 10px;
        }
        
        .control-center-list {
        background: none;
        }
        
        .control-center-list-placeholder {
        opacity: 0.0;
        }
        
        .floating-notifications {
        background: none;
        }
        
        /* Window behind control center and on all other monitors */
        .blank-window {
        background: alpha(black, 0.25);
        }
        
        /*** Widgets ***/
        
        /* Title widget */
        .widget-title {
        margin: 12px;
        font-size: 1.5rem;
        }
        .widget-title > button {
        font-size: initial;
        color: @text;
        text-shadow: none;
        background: @noti-bg;
        border: 1px solid @noti-border-color;
        box-shadow: none;
        border-radius: 10px;
        }
        .widget-title > button:hover {
        background: @noti-bg-hover;
        }
        .widget-title > button:active {
        background: @noti-bg;
        }
        
        /* DND widget */
        .widget-dnd {
        margin: 12px;
        font-size: 1.1rem;
        }
        .widget-dnd > switch {
        font-size: initial;
        border-radius: 10px;
        background: @noti-bg;
        border: 1px solid @noti-border-color;
        box-shadow: none;
        }
        .widget-dnd > switch:checked {
        background: @bg-selected;
        }
        .widget-dnd > switch slider {
        background: @noti-bg-hover;
        border-radius: 10px;
        }
        
        /* Label widget */
        .widget-label {
        margin: 12px;
        }
        .widget-label > label {
        font-size: 1.1rem;
        }
        
        /* Mpris widget */
        .widget-mpris {
        /* The parent to all players */
        }
        .widget-mpris-player {
        padding: 12px;
        margin: 12px;
        margin-top: 0;
        background-color: @mpris-bg;
        border-radius: 10px;
        }
        .widget-mpris-title {
        font-weight: bold;
        font-size: 1.25rem;
        }
        .widget-mpris-subtitle {
        font-size: 1.1rem;
        }
        
        /* Buttons widget */
        .widget-buttons-grid {
        padding: 12px;
        margin: 12px;
        border-radius: 10px;
        background-color: @noti-bg;
        }
        
        .widget-buttons-grid>flowbox>flowboxchild>button{
        background: @noti-bg;
        border-radius: 10px;
        }
        
        .widget-buttons-grid>flowbox>flowboxchild>button:hover {
        background: @noti-bg-hover;
        }
        
        /* Menubar widget */
        .widget-menubar>box>.menu-button-bar>button {
        border: none;
        background: none;
        }
        
        /* .AnyName { Name defined in config after #
        background-color: @noti-bg;
        padding: 12px;
        margin: 12px;
        border-radius: 10px;
        }
        
        .AnyName>button {
        background: none;
        border: none;
        }
        
        .AnyName>button:hover {
        background-color: @noti-bg-hover;
        } */
        
        .topbar-buttons>button { /* Name defined in config after # */
        border: none;
        background: none;
        }
        
        /* Volume widget */
        
        .widget-volume {
        background-color: @mpris-bg;
        padding: 12px;
        margin: 12px;
        border-radius: 10px;
        font-size: 30px;
        }
        
        /* Backlight widget */
        .widget-backlight {
        background-color: @noti-bg;
        padding: 12px;
        margin: 12px;
        border-radius: 10px;
        }
        
        /* Title widget */
        .widget-inhibitors {
        margin: 12px;
        font-size: 1.5rem;
        }
    '';
  };
}