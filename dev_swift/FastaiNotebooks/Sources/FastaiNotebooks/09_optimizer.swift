/*
THIS FILE WAS AUTOGENERATED! DO NOT EDIT!
file to edit: 09_optimizer.ipynb

*/
        
import Path
import TensorFlow

open class StatDelegate<Scalar: TensorFlowFloatingPoint> {
    open var name: String { return "" }
    var defaultConfig: HeterogeneousDictionary { return HeterogeneousDictionary() }
    func update(
        state: inout [String: Tensor<Scalar>],
        for param: Tensor<Scalar>,
        along direction: Tensor<Scalar>,
        config: inout HeterogeneousDictionary
    ) { }
}

//export
open class StepDelegate<Scalar: TensorFlowFloatingPoint> {
    var defaultConfig: HeterogeneousDictionary { return HeterogeneousDictionary() }
    func update(
        param: inout Tensor<Scalar>,
        along direction: inout Tensor<Scalar>,
        state: [String: Tensor<Scalar>],
        config: inout HeterogeneousDictionary
    ) { }
}

class StatefulOptimizer<Model: Layer,
                        Scalar: TensorFlowFloatingPoint>: Optimizer
    where Model.AllDifferentiableVariables == Model.CotangentVector{
    var config: HeterogeneousDictionary
    var learningRate: Float {
        get { return config[LearningRate()] } 
        set { config[LearningRate()] = newValue }
    }
    var states: [String: Model.AllDifferentiableVariables]
    var statDelegates: [StatDelegate<Scalar>]
    var stepDelegates: [StepDelegate<Scalar>]
    init(
        stepDelegates: [StepDelegate<Scalar>],
        statDelegates: [StatDelegate<Scalar>],
        config: HeterogeneousDictionary
    ) {
        self.config = HeterogeneousDictionary()
        states = [:]
        for stepDelegate in stepDelegates {
            self.config.merge(stepDelegate.defaultConfig) { (_, new) in new }
        }
        for statDelegate in statDelegates {
            self.config.merge(statDelegate.defaultConfig) { (_, new) in new }
            states[statDelegate.name] = Model.AllDifferentiableVariables.zero
        }
        self.config.merge(config) { (_, new) in new }
        self.stepDelegates = stepDelegates
        self.statDelegates = statDelegates
    }
    func update(
        _ model: inout Model.AllDifferentiableVariables,
        along direction: Model.CotangentVector
    ) {
        for kp in model.recursivelyAllWritableKeyPaths(to: Tensor<Scalar>.self) {
            var grad = direction[keyPath: kp]
            var state = states.mapValues(){$0[keyPath: kp]}
            for statDelegate in statDelegates {
                statDelegate.update(
                    state: &state,
                    for: model[keyPath: kp],
                    along: grad,
                    config: &config
                )
            }
            for n in states.keys { states[n]![keyPath: kp] = state[n]! }
            for stepDelegate in stepDelegates {
                stepDelegate.update(
                    param: &model[keyPath: kp],
                    along: &grad,
                    state: state,
                    config: &config
                )
            }
        }
    }
}

class SGDStep: StepDelegate<Float> {
    override func update(
        param: inout Tensor<Float>,
        along direction: inout Tensor<Float>,
        state: [String: Tensor<Float>],
        config: inout HeterogeneousDictionary
    ) {
        param -= direction * config[LearningRate()]
    }
}

public struct WeightDecayKey: HetDictKey, Equatable {
    public static var defaultValue: Float = 0.0
}

class WeightDecay: StepDelegate<Float> {
    override func update(
        param: inout Tensor<Float>,
        along direction: inout Tensor<Float>,
        state: [String: Tensor<Float>],
        config: inout HeterogeneousDictionary
    ) {
        param *= 1 - config[LearningRate()] * config[WeightDecayKey()]
    }
}


class L2Regularization: StepDelegate<Float> {
    override func update(
        param: inout Tensor<Float>,
        along direction: inout Tensor<Float>,
        state: [String: Tensor<Float>],
        config: inout HeterogeneousDictionary
    ) {
        direction += config[WeightDecayKey()] * param
    }
}


public struct Momentum: HetDictKey, Equatable {
    public static var defaultValue: Float = 0.9
}

public struct MomentumDampening: HetDictKey, Equatable {
    public static var defaultValue: Float = 0.9
}

class AverageGrad: StatDelegate<Float> {
    let dampened: Bool
    init(dampened: Bool = false) { self.dampened = dampened }
    override var name: String { return "averageGrad" }
    override func update(
        state: inout [String: Tensor<Float>],
        for param: Tensor<Float>,
        along direction: Tensor<Float>,
        config: inout HeterogeneousDictionary
    ) {
        state["averageGrad"]! *= config[Momentum()]
        config[MomentumDampening()] = 1.0 - (dampened ? config[Momentum()] : 0.0)
        state["averageGrad"]! += config[MomentumDampening()] * direction
    }
}

class MomentumStep: StepDelegate<Float> {
    override func update(
        param: inout Tensor<Float>,
        along direction: inout Tensor<Float>,
        state: [String: Tensor<Float>],
        config: inout HeterogeneousDictionary
    ) {
        param -= config[LearningRate()] * state["averageGrad"]!
    }
}


public struct SquareMomentum: HetDictKey, Equatable {
    public static var defaultValue: Float = 0.99
}

public struct SquareMomentumDampening: HetDictKey, Equatable {
    public static var defaultValue: Float = 0.99
}


class AverageSquaredGrad: StatDelegate<Float> {
    let dampened: Bool
    init(dampened: Bool = false) { self.dampened = dampened }
    override var name: String { return "averageSquaredGrad" }
    override func update(
        state: inout [String: Tensor<Float>],
        for param: Tensor<Float>,
        along direction: Tensor<Float>,
        config: inout HeterogeneousDictionary
    ) {
        state["averageSquaredGrad"]! *= config[SquareMomentum()]
        config[SquareMomentumDampening()] = 1.0 - (dampened ? config[SquareMomentum()] : 0.0)
        state["averageSquaredGrad"]! += config[SquareMomentumDampening()] * direction.squared()
    }
}

class StepCount: StatDelegate<Float> {
    override var name: String { return "step" }
    override func update(
        state: inout [String: Tensor<Float>],
        for param: Tensor<Float>,
        along direction: Tensor<Float>,
        config: inout HeterogeneousDictionary
    ) {
        state["step"]! += 1.0
    }
}

func debias<Scalar: TensorFlowFloatingPoint>(
    momentum: Scalar,
    dampening: Scalar,
    step: Tensor<Scalar> 
) -> Tensor<Scalar> {
    return dampening * (1 - pow(momentum, step)) / (1 - momentum)
}

public struct Epsilon: HetDictKey, Equatable {
    public static var defaultValue: Float = 1e-5
}

class AdamStep: StepDelegate<Float> {
    override func update(
        param: inout Tensor<Float>,
        along direction: inout Tensor<Float>,
        state: [String: Tensor<Float>],
        config: inout HeterogeneousDictionary
    ) {
        let debiasedLearningRate = config[LearningRate()] / debias(
            momentum: config[Momentum()],
            dampening: config[MomentumDampening()],
            step: state["step"]!
        )
        let debiasedRMSGrad = sqrt(state["averageSquaredGrad"]! / debias(
            momentum: config[SquareMomentum()],
            dampening: config[SquareMomentumDampening()],
            step: state["step"]!
        )) + config[Epsilon()]
        param -= debiasedLearningRate * state["averageGrad"]! / debiasedRMSGrad
    }
}
