//
//  TimerViewModel.swift
//  MealieRecipes
//
//  Created by Michael Haiszan on 30.04.25.
//

import UIKit
import Foundation
import AVFoundation
import UserNotifications
import AudioToolbox

@MainActor
class TimerViewModel: ObservableObject {
    @Published var timerActive = false
    @Published var timeRemaining: TimeInterval = 0

    private var endTime: Date?
    private var timer: Timer?
    private var audioPlayer: AVAudioPlayer?

    func start(durationMinutes: Double) {
        let totalSeconds = durationMinutes * 60
        endTime = Date().addingTimeInterval(totalSeconds)
        timeRemaining = totalSeconds
        timerActive = true

        triggerNotification(after: totalSeconds)
        UIApplication.shared.applicationIconBadgeNumber = Int(durationMinutes)

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateRemainingTime()
        }

        print("▶️ Timer gestartet bis \(String(describing: endTime))")
    }

    func stop() {
        timer?.invalidate()
        endTime = nil
        timerActive = false
        timeRemaining = 0
        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    private func updateRemainingTime() {
        guard let endTime else { return }

        let remaining = endTime.timeIntervalSinceNow
        timeRemaining = max(0, remaining)

        UIApplication.shared.applicationIconBadgeNumber = Int(timeRemaining / 60)

        if timeRemaining <= 0 {
            stop()
            playSound()
        }
    }

    private func playSound() {
        if let soundURL = Bundle.main.url(forResource: "alarm", withExtension: "wav") {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
                try AVAudioSession.sharedInstance().setActive(true)
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer?.play()
                print("🔊 Sound gespielt")
            } catch {
                print("❌ Soundfehler: \(error)")
                AudioServicesPlaySystemSound(1005)
            }
        } else {
            print("⚠️ alarm.wav nicht gefunden")
            AudioServicesPlaySystemSound(1005)
        }
    }

    private func triggerNotification(after seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Timer abgelaufen!"
        content.body = "Dein Timer ist fertig."
        content.sound = UNNotificationSound(named: UNNotificationSoundName("alarm.wav"))
        content.badge = 0

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: "timer_end", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Notification-Fehler: \(error)")
            }
        }
    }
}
