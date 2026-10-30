import QtQuick

// SpringAnimation preset. Set token to a Theme.springs key, such as "spatialDefault".
SpringAnimation {
    id: opalSpring
    property string token: "spatialDefault"
    readonly property var config: Theme.springs[token] || Theme.springs.spatialDefault
    // Qt applies spring and damping once per 16 ms step, so the M3 values are multiplied by the step time.
    readonly property real step: 0.016
    // Damping above 1 per step makes the Qt integration unstable, so it is limited to 0.95.
    spring: Theme.reduceMotion ? 1/step : config.stiffness*step
    damping: Theme.reduceMotion ? 1 : Math.min(0.95, 2*config.ratio*Math.sqrt(config.stiffness)*step)
    mass: 1
    epsilon: 0.005
}
