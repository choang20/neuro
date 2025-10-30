//
//  CircleAnimation.swift
//  Drawings
//
//  Created by Max Taggart on 5/21/25.
//

import SwiftUI
import SpriteKit
import Combine

//let excursion_size_pixels: CGFloat = UIScreen.current!.bounds.height
//let excursion_size_inches: CGFloat = UIScreen.current!.bounds.height / iPhone14_ppi

enum MotionMode {
    case triangle
    case sine
}

struct BackAndForthStimulus: View {
    @State private var cycle_count: Int = 0
    let dot_speed_publisher: AnyPublisher<TimestampedValue<CGFloat>, Never>
    let dot_position_subject: PassthroughSubject<TimestampedValue<CGPoint>, Never>
    var motion: MotionMode = .triangle
    
    var scene: SKScene {
        let scene = MovingCircleScene(
            size: CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height),
            dot_speed_publisher: dot_speed_publisher,
            dot_position_subject: dot_position_subject,
            motion: motion
        )
        scene.scaleMode = .resizeFill
        return scene
    }

    var body: some View {
        SpriteView(scene: scene)
            .frame(height: 300)
            .background(Color.black.opacity(0.05))
    }
}

enum Direction {
    case Left
    case Right
}

let iPhone14_ppi: CGFloat = 460.0

class MovingCircleScene: SKScene {
    let dot_speed_publisher: AnyPublisher<TimestampedValue<CGFloat>, Never>
    let dot_position_subject: PassthroughSubject<TimestampedValue<CGPoint>, Never>
    let motion: MotionMode
    private var speed_consumer_task: Task<(), Never>!
    private var consumer_handle: AnyCancellable!
    private var circleNode: SKShapeNode!
    private var radius: CGFloat = 20
    private var start_x: CGFloat!
    private var target_x: CGFloat!
    private var y: CGFloat!
    private var previous_frame_time: TimeInterval!
    private var previous_x: CGFloat = 0
    private var direction: Direction = .Right
    
    private var current_pixels_per_second: CGFloat = 0
    private var phase: CGFloat = 0 // for sine

    init(
        size: CGSize,
        dot_speed_publisher: AnyPublisher<TimestampedValue<CGFloat>, Never>,
        dot_position_subject: PassthroughSubject<TimestampedValue<CGPoint>, Never>,
        motion: MotionMode
    ) {
        self.dot_speed_publisher = dot_speed_publisher
        self.dot_position_subject = dot_position_subject
        self.motion = motion
        super.init(size: size)
        self.speed_consumer_task = Task {
            self.consumer_handle = dot_speed_publisher.sink { v in
                let speed = v.value
                self.current_pixels_per_second = speed
            }
        }
    }
    
    // This is a required method on SKScene but it is only called when/if this
    // class is loaded from a storyboard file (.sks) which is never the case
    // for this app.
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /*
     Called once when this scene is presented by a view.
    */
    override func didMove(to view: SKView) {
        backgroundColor = .white

        // Create red circle
        let diameter = targetDotDiameterPixels()
        radius = diameter / 2
        circleNode = SKShapeNode(circleOfRadius: radius)
        circleNode.fillColor = .red
        circleNode.strokeColor = .clear
        y = round(size.height / 2)
        circleNode.position = CGPoint(x: radius, y: y)
        addChild(circleNode)

        // Add black center dot (~25% diameter)
        let centerNode = SKShapeNode(circleOfRadius: radius * 0.25)
        centerNode.fillColor = .black
        centerNode.strokeColor = .clear
        centerNode.position = CGPoint(x: 0, y: 0)
        circleNode.addChild(centerNode)

        // Animate to the right side of the screen
        start_x = radius
        target_x = size.width - radius
    }

    override func didChangeSize(_ oldSize: CGSize) {
        // Optionally update the animation when size changes
        target_x = size.width - radius
        y = round(size.height / 2)
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
        if previous_frame_time == nil {
            previous_frame_time = currentTime
        }
        let time_delta: TimeInterval = currentTime - previous_frame_time
        previous_frame_time = currentTime
        
        var new_x: CGFloat = circleNode.position.x
        switch motion {
        case .triangle:
            let delta_x = current_pixels_per_second * time_delta
            var finished_excursion = false
            if direction == .Left {
                new_x = circleNode.position.x - delta_x
                if new_x < start_x! { new_x = start_x!; finished_excursion = true }
            } else {
                new_x = circleNode.position.x + delta_x
                if new_x > target_x! { new_x = target_x!; finished_excursion = true }
            }
            if finished_excursion {
                direction = (direction == .Left) ? .Right : .Left
            }
        case .sine:
            // amplitude and center
            let center = (start_x + target_x) / 2
            let A = (target_x - start_x) / 2
            let omega = max(current_pixels_per_second / max(A, 1), 0) // rad/s in px: peak speed = A*omega
            phase += omega * time_delta
            new_x = center + A * sin(phase)
        }

        circleNode.position.x = round(Double(new_x))
        // Publish the new position
        dot_position_subject.send(
            TimestampedValue.from(CGPoint(x: CGFloat(circleNode.position.x), y: y))
        )
    }
}



//#Preview {
//    Stimulus()
//}
