# Auto Dark Mode

Auto Dark Mode switches Omarchy between a chosen light and dark theme at the
local solar boundary. It runs entirely inside the Omarchy shell and performs
the astronomical calculation locally; coordinates are never sent anywhere.

## Install

```sh
omarchy plugin add https://github.com/digitalfrost84/omarchy-auto-dark-mode-plugin --enable
```

The plugin starts with automatic switching disabled and does not assume a
location. Click the new sun/moon icon, enter coordinates, choose themes, save,
and turn on **Automatic**.

## Configure

The popup provides:

- latitude and longitude
- civil dawn/dusk or sunrise/sunset
- independent dawn and dusk offsets in minutes
- light and dark themes selected from the themes installed in Omarchy

Negative offsets happen before an event; positive offsets happen after it.
Middle-click the widget to re-evaluate immediately. Selecting **Light now** or
**Dark now** temporarily overrides automation until the next solar transition,
including across shell restarts.

If the shell is not currently running, enable the plugin after installation:

```sh
omarchy plugin enable digitalfrost84.auto-dark-mode
```

## Privacy and dependencies

The plugin uses no network services and adds no package dependencies. It runs
unsandboxed with normal user permissions, like all Omarchy shell plugins, and
only launches the local `omarchy theme list`, `current`, and `set`
commands. Manual-override state is stored at
`~/.local/state/omarchy/auto-dark-mode.json`.

## Remove

```sh
omarchy plugin remove digitalfrost84.auto-dark-mode
```

Removal stops the service and removes the widget. The small manual-override
state file may be deleted separately if desired.

## Development

```sh
omarchy plugin validate ~/.config/omarchy/plugins/digitalfrost84.auto-dark-mode
/usr/lib/qt6/bin/qmllint -I /usr/share/omarchy/shell ~/.config/omarchy/plugins/digitalfrost84.auto-dark-mode/*.qml
node tests/test-solar.js
```
