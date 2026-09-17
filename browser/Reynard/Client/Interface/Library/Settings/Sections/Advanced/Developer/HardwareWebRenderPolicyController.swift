//
//  HardwareWebRenderPolicyController.swift
//  Reynard
//
//  Opt-in GPU compositing (hardware WebRender) for the Developer settings.
//  Off by default: the win is limited to compositor-bound work (pure CSS
//  animations ~40%), while heavy pages risk the A7 GPU driver crash and
//  extra GPU textures add jetsam pressure on 1GB devices.
//  Backend is chosen at gfx init (AtStartup prefs), so toggling requires
//  a cold restart; the settings footer says so.

import GeckoView

enum HardwareWebRenderPolicyController {
    static func applyHardwareWebRender() {
        guard Prefs.DeveloperSettings.hardwareWebRenderEnabled else {
            return
        }
        GeckoRuntime.setDefaultPrefs([
            "gfx.webrender.all": true,
            "gfx.webrender.software": false,
        ])
    }
}
