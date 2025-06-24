//
//  CircleAnimation.swift
//  Drawings
//
//  Created by Max Taggart on 5/21/25.
//

import SwiftUI
import SpriteKit


//let excursion_size_pixels: CGFloat = UIScreen.current!.bounds.height
//let excursion_size_inches: CGFloat = UIScreen.current!.bounds.height / iPhone14_ppi

struct Stimulus: View {
    @State private var cycle_count: Int = 0
    let patient_info: PatientInfo?
    @Binding var storage_manager: StorageManager
    var on_completed_test: () -> Void
    
    var scene: SKScene {
        let scene = MovingCircleScene(
            size: CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height),
            on_completed_test: on_completed_test,
            wrap: false,
            patient_info: patient_info,
            storage_manager: $storage_manager
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

let speed_cycles: [(Int, Int)] = [
    (3, 2),
    (4, 2),
//    (5, 2),
//    (7, 2),
//    (8, 2),
//    (10, 2),
//    (12, 2),
//    (15, 2),
//    (17, 2),
//    (20, 4),
//    (24, 4),
//    (28, 4),
//    (30, 4),
//    (32, 4),
//    (34, 4),
]

let iPhone14_ppi: CGFloat = 460.0

class MovingCircleScene: SKScene {
    private var on_completed_test: () -> Void
    private var wrap: Bool
    private var patient_info: PatientInfo?
    private var session_sink: SessionSink
    private var circleNode: SKShapeNode!
    private var radius: CGFloat = 20
    private var start_x: CGFloat!
    private var target_x: CGFloat!
    private var y: CGFloat!
    private var previous_frame_time: TimeInterval!
    private var previous_x: CGFloat = 0
    private var direction: Direction = .Right
    let spatial_emitter: SpatialDataEmitter = SpatialDataEmitter()
    
    private var current_speed_cycle_index: Int = 0
    private var remaning_excursions: Int = speed_cycles[0].1
    private var current_pixels_per_second: CGFloat = 0
    private var spatial_emitter_task: Task<Void, Never>!
    private var update_count: Int = 0

    init(
        size: CGSize,
        on_completed_test: @escaping () -> Void,
        wrap: Bool,
        patient_info: PatientInfo?,
        storage_manager: Binding<StorageManager>
    ) {
        self.on_completed_test = on_completed_test
        self.wrap = wrap
        self.patient_info = patient_info
        self.session_sink = SessionSink(
            storage_manager: storage_manager, patient_info: patient_info)
        super.init(size: size)
        self.spatial_emitter_task = Task {
            for await frame_data in await spatial_emitter.stream {
                switch frame_data {
                case .NoFaceDetected:
                    print("No Face Detected")
                case .FaceDetected(let data):
                    let eye_distance_inches = calculate_distance_from_screen(
                        from_transforms: data.transforms)
                    let (degrees_per_second, _) = speed_cycles[current_speed_cycle_index]
                    // Calculate pixels per second given distance and width
                    current_pixels_per_second = iPhone14_ppi * CGFloat(eye_distance_inches) * tan(CGFloat(Float.pi / 180.0) * CGFloat(degrees_per_second))
                    session_sink.add_row(Row(
                        transforms: data.transforms, degrees_per_second: degrees_per_second
                    ))
                }
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
        circleNode = SKShapeNode(circleOfRadius: radius)
        circleNode.fillColor = .red
        circleNode.strokeColor = .clear
        y = round(size.height / 2)
        circleNode.position = CGPoint(x: radius, y: y)
        addChild(circleNode)

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
        self.update_count += 1
        // Check if the exam is already over
        if self.current_speed_cycle_index >= speed_cycles.count {
                return
        }
        // Called before each frame is rendered
        if previous_frame_time == nil {
            previous_frame_time = currentTime
        }
        let time_delta: TimeInterval = currentTime - previous_frame_time
        previous_frame_time = currentTime
        
        // Calculate the current position
        // Negate the delta_x if we are not in
        // wrap mode and we are on a leftward excursion
        let delta_x = current_pixels_per_second * time_delta
//        print("Current px/s: \(current_pixels_per_second)")
//        print("Delta time: \(time_delta)")
//        print("Delta x: \(delta_x)")
        var new_x: Double
        var finished_excursion: Bool = false
        if direction == .Left {
            new_x = circleNode.position.x - delta_x
            if new_x < start_x! {
                // We have finished an excursion
                if wrap {
                    new_x = target_x!
                } else {
                    new_x = start_x!
                }
                finished_excursion = true
            }
        } else {
            // Direction is right
            new_x = circleNode.position.x + delta_x
            if new_x > target_x! {
                // We have finished an excursion
                if wrap {
                    new_x = start_x!
                } else {
                    new_x = target_x!
                }
                finished_excursion = true
            }
        }
        // Check if we have completed an excursion
        if finished_excursion {
            // Decrement our remaining excursion count
            self.remaning_excursions -= 1
            if self.remaning_excursions == 0 {
                // Checkin to see if we have finished the test
                if self.current_speed_cycle_index == speed_cycles.count - 1 {
                    self.test_complete()
                    on_completed_test()
                    return
                } else {
                    // Increment our cycle index
                    self.current_speed_cycle_index += 1
                    self.remaning_excursions = speed_cycles[self.current_speed_cycle_index].1
                }
            }
            // Switch direction if we are not in wrap mode
            if !wrap {
                switch direction {
                case .Left:
                    direction = .Right
                case .Right:
                    direction = .Left
                }
            }
        }
        
        // Set the new position
        circleNode.position.x = round(new_x)
    }
    
    override func willMove(from view: SKView) {
        super.willMove(from: view)
        // We may end up referencing spatial_emitter and spatial_emitter_task after the class has already been destroyed
        Task {
            await self.spatial_emitter.end_capture()
            self.spatial_emitter_task.cancel()
        }
        
    }
    
    private func test_complete() {
        self.session_sink.done()
        self.spatial_emitter_task.cancel()
    }
}

func interpolate_linear(relative_time: Double, start: CGFloat, end: CGFloat) -> CGFloat {
    if relative_time < 0 {
        return start
    }
    if relative_time > 1 {
        return end
    }
    let current = (end - start) * CGFloat(relative_time) + start
    return current
}

//class MovingCircleScene: SKScene {
//    private var circleNode: SKShapeNode!
//
//    /*
//     Called once when this scene is presented by a view.
//    */
//    override func didMove(to view: SKView) {
//        backgroundColor = .white
//
//        // Create red circle
//        let radius: CGFloat = 20
//        circleNode = SKShapeNode(circleOfRadius: radius)
//        circleNode.fillColor = .red
//        circleNode.strokeColor = .clear
//        circleNode.position = CGPoint(x: radius, y: size.height / 2)
//        addChild(circleNode)
//
//        // Animate to the right side of the screen
//        let targetX = size.width - radius
//        let moveAction = SKAction.move(to: CGPoint(x: targetX, y: size.height / 2), duration: 2.0)
//        moveAction.timingMode = .easeInEaseOut
//        circleNode.run(moveAction)
//    }
//
//    override func didChangeSize(_ oldSize: CGSize) {
//        // Optionally update the animation when size changes
//    }
//}

#Preview {
    let patient_info = PatientInfo(
        first_name: "Test", last_name: "Patient", birth_date: Date(), sex: .Male, race: .White, ethnicity: .NotHispanic
    )
    Stimulus(
        patient_info: patient_info,
        storage_manager: .constant(StorageManager()),
        on_completed_test: {}
    )
}
