//
//  ViewController.swift
//  Strange Attractors in Metal
//
//  Created by Eduard Dzhumagaliev on 15.08.2021.
//

import MetalKit
import PureLayout

class ViewController: UIViewController {
    public var device: MTLDevice!
    var queue: MTLCommandQueue!

    var particleBuffer: MTLBuffer!
    let particleCount = 50000
    var particles = [Particle]()
    var computePipelineFirstState: MTLComputePipelineState!
    var computePipelineSecondState: MTLComputePipelineState!

    private weak var metalView: MTKView?

    private weak var overlayView: UIView?
    private weak var stackView: UIStackView?

    private weak var firstCard: UIButton?
    private weak var secondCard: UIButton?
    private weak var thirdCard: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()

        device = MTLCreateSystemDefaultDevice()
        queue = device.makeCommandQueue()

        registerShaders()
        initializeBuffers()
        initSubviews()
//        initConstraints()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        get {
            .darkContent
        }
    }
}

private extension ViewController {
    func registerShaders() {
        do {
            let library = device.makeDefaultLibrary()
            guard let firstPass = library?.makeFunction(name: "firstPass") else { return }
            computePipelineFirstState = try device.makeComputePipelineState(function: firstPass)
            guard let secondPass = library?.makeFunction(name: "secondPass") else { return }
            computePipelineSecondState = try device.makeComputePipelineState(function: secondPass)
        } catch let e {
            print(e)
        }
    }

    func initializeBuffers() {
        guard let screen = UIScreen.screens.first else { return }
        let width = screen.nativeBounds.width
        let height = screen.nativeBounds.height
        for _ in 0..<particleCount{
            let particle = Particle(
                position: SIMD3<Float>(Float(arc4random() %  UInt32(width * 2)),
                                       Float(arc4random() % UInt32(height)),
                                       Float.random(in: -1000...1000)),
                velocity: SIMD3<Float>((Float(arc4random() %  10) - 5) / 10,
                                       (Float(arc4random() %  10) - 5) / 10,
                                       Float.random(in: -100...100)))
            particles.append(particle)
        }

        let a: Float = 10.0;
        let b: Float = 28.0;
        let c: Float = 2.6666666667;
        let dt: Float = 0.00001;

        for _ in 0..<1000 {
            particles = particles.map({ particle in
                var newParticle = particle
                let x = particle.position.x / Float(width) * 15
                let y = particle.position.y / Float(height) * 20
                let z = particle.position.z / 1000.0 * 45

                let dx = (a * (y - x)) * dt
                let dy = (x * (b - z) - y) * dt
                let dz = (x * y - c * z) * dt

                let attractorForce = SIMD3<Float>(x: dx, y: dy, z: dz) * SIMD3<Float>(x: Float(width), y: Float(height), z: 1000.0)
                newParticle.position = newParticle.position + attractorForce

                return newParticle
            })
        }

        let size = particles.count * MemoryLayout<Particle>.size
        particleBuffer = device.makeBuffer(bytes: &particles, length: size, options: [])
    }

    func initSubviews() {
        initMetalView()
//        initOverlay()
    }

    func initMetalView() {
        let metalView = MTKView(frame: view.frame, device: device)
        metalView.framebufferOnly = false
        metalView.delegate = self
        view.addSubview(metalView)
        self.metalView = metalView
    }

    func initOverlay() {
        let overlayView = UIVisualEffectView()
        let effect = UIBlurEffect(style: .dark)
        overlayView.effect = effect
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.layer.cornerRadius = 10
        overlayView.clipsToBounds = true
        overlayView.layer.zPosition = 5
        overlayView.layoutMargins.left = 15.0
        overlayView.layoutMargins.right = 15.0
        overlayView.contentView.preservesSuperviewLayoutMargins = true
        view.addSubview(overlayView)
        self.overlayView = overlayView

        let stackView = UIStackView()
        stackView.distribution = .fillEqually
        stackView.spacing = 15.0
        overlayView.contentView.addSubview(stackView)
        self.stackView = stackView

        let firstCard = UIButton(type: .custom)
        firstCard.layer.cornerRadius = 10
        firstCard.layer.borderWidth = 1.0
        firstCard.backgroundColor = .white
        firstCard.clipsToBounds = true
        stackView.addArrangedSubview(firstCard)

        let secondCard = UIButton(type: .custom)
        secondCard.layer.cornerRadius = 10
        secondCard.layer.borderWidth = 1.0
        secondCard.backgroundColor = .white
        secondCard.clipsToBounds = true
        stackView.addArrangedSubview(secondCard)

        let thirdCard = UIButton(type: .custom)
        thirdCard.layer.cornerRadius = 10
        thirdCard.layer.borderWidth = 1.0
        thirdCard.backgroundColor = .white
        thirdCard.clipsToBounds = true
        stackView.addArrangedSubview(thirdCard)
    }

    func initConstraints() {
        overlayView?.autoPinEdge(toSuperviewSafeArea: .bottom, withInset: 20.0)
        overlayView?.autoPinEdge(toSuperviewMargin: .left)
        overlayView?.autoPinEdge(toSuperviewMargin: .right)
        overlayView?.autoSetDimension(.height, toSize: 124.0)

        stackView?.autoPinEdge(toSuperviewMargin: .left)
        stackView?.autoPinEdge(toSuperviewMargin: .right)
        stackView?.autoPinEdge(toSuperviewEdge: .top, withInset: 15.0)
        stackView?.autoPinEdge(toSuperviewEdge: .bottom, withInset: 15.0)

        firstCard?.autoPinEdge(toSuperviewEdge: .top)
        firstCard?.autoPinEdge(toSuperviewEdge: .bottom)

        secondCard?.autoPinEdge(toSuperviewEdge: .top)
        secondCard?.autoPinEdge(toSuperviewEdge: .bottom)

        thirdCard?.autoPinEdge(toSuperviewEdge: .top)
        thirdCard?.autoPinEdge(toSuperviewEdge: .bottom)
    }
}

extension ViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        if let drawable = view.currentDrawable,
           let commandBuffer = queue.makeCommandBuffer(),
           let commandEncoder = commandBuffer.makeComputeCommandEncoder() {
            /**
             # First Pass
             It's all about *drawing background*
             */
            commandEncoder.setComputePipelineState(computePipelineFirstState)
            commandEncoder.setTexture(drawable.texture, index: 0)
            var w = computePipelineFirstState.threadExecutionWidth
            var h = computePipelineFirstState.maxTotalThreadsPerThreadgroup / w
            var threadsPerGroup = MTLSizeMake(w, h, 1)
            var threadsPerGrid = MTLSizeMake(drawable.texture.width, drawable.texture.height, 1)
            commandEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
            /**
             # Second Pass
             It's all about *drawing particles*
             */
            commandEncoder.setComputePipelineState(computePipelineSecondState)
            commandEncoder.setTexture(drawable.texture, index: 0)
            w = computePipelineSecondState.threadExecutionWidth
            h = computePipelineSecondState.maxTotalThreadsPerThreadgroup / w
            threadsPerGroup = MTLSizeMake(1, 1, 1)
            commandEncoder.setBuffer(particleBuffer, offset: 0, index: 0)
            threadsPerGrid = MTLSizeMake(particleCount, 1, 1)
            commandEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)

            commandEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
