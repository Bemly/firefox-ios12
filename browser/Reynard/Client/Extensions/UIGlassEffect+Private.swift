//
//  UIGlassEffect+Private.swift
//  Reynard
//
//  Created by Minh Ton on 8/8/26.
//

import UIKit

@available(iOS 26.0, *)
extension UIGlassEffect {
    // Disable the adaptive effect of UIGlassEffect to prevent it from changing its appearance
    // based on the underlying content
    static func nonAdaptive(style: Style) -> UIGlassEffect {
        let effect = UIGlassEffect(style: style)
        let glassSelector = Selector(("glass"))
        typealias GlassGetter = @convention(c) (AnyObject, Selector) -> Unmanaged<AnyObject>
        let getGlass = unsafeBitCast(effect.method(for: glassSelector), to: GlassGetter.self)
        let glass = getGlass(effect, glassSelector).takeUnretainedValue()
        
        let adaptiveSelector = Selector(("setAdaptive:"))
        typealias SetAdaptive = @convention(c) (AnyObject, Selector, Bool) -> Void
        let setAdaptive = unsafeBitCast(glass.method(for: adaptiveSelector), to: SetAdaptive.self)
        setAdaptive(glass, adaptiveSelector, false)
        
        let factorySelector = Selector(("effectWithGlass:"))
        let factoryMethod = class_getClassMethod(UIGlassEffect.self, factorySelector)!
        typealias GlassEffectFactory = @convention(c) (AnyObject, Selector, AnyObject) -> Unmanaged<AnyObject>
        let makeGlassEffect = unsafeBitCast(method_getImplementation(factoryMethod), to: GlassEffectFactory.self)
        return makeGlassEffect(UIGlassEffect.self, factorySelector, glass).takeUnretainedValue() as! UIGlassEffect
    }
}
