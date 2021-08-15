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
    var computePipelineState: MTLComputePipelineState!
    var timerBuffer: MTLBuffer!
    var timer: Float = 0

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
        initSubviews()
        initConstraints()
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
            guard let library = device.makeDefaultLibrary() else { return }
            guard let kernel = library.makeFunction(name: "compute") else { return }
            computePipelineState = try device.makeComputePipelineState(function: kernel)
        } catch {
            print("\(error)")
        }
        timerBuffer = device.makeBuffer(length: MemoryLayout<Float>.size, options: [])
    }

    func initSubviews() {
        initMetalView()
        initOverlay()
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
    func update() {
        timer += 0.01
        let bufferPointer = timerBuffer.contents()
        memcpy(bufferPointer, &timer, MemoryLayout<Float>.size)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        if let drawable = view.currentDrawable,
           let commandBuffer = queue.makeCommandBuffer(),
           let commandEncoder = commandBuffer.makeComputeCommandEncoder() {
            commandEncoder.setComputePipelineState(computePipelineState)
            commandEncoder.setBuffer(timerBuffer, offset: 0, index: 0)
            commandEncoder.setTexture(drawable.texture, index: 0)
            update()
            let threadGroupCount = MTLSizeMake(8, 8, 1)
            let threadGroups = MTLSizeMake(drawable.texture.width / threadGroupCount.width, drawable.texture.height / threadGroupCount.height, 1)
            commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
            commandEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
