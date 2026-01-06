//
//  AppDelegate.swift
//  IntellaRoom
//
//  Created by Kenneth Riendeau on 1/6/26.
//
import SwiftUI
import Firebase


class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
      

      let db = Firestore.firestore()
      print("🔥 Firestore instance:", db)
      
    return true
  }
}
