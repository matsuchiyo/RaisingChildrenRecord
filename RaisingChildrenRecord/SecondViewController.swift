//
//  SecondViewController.swift
//  RaisingChildrenRecord
//
//  Created by 松島勇貴 on 2018/07/12.
//  Copyright © 2018年 松島勇貴. All rights reserved.
//

import UIKit

import RealmSwift

import CustomRealmObject

import Firebase

class SecondViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    
    var token: NotificationToken?
    
    var sections: [(header: String, cells: [(label1: String, label2: String)])]
        = [(header: "赤ちゃんを切り替える", cells: []),
           (header: "赤ちゃんを編集する", cells: []),
           (header: "データ共有", cells: [(label1: "家族を新規作成する", label2: ""), (label1: "他の人を家族に加える", label2: ""), (label1: "既存の家族に加わる", label2: ""), (label1: "共有しているデータを削除する", label2: "")])]
    var babies: Array<Baby> = []
    
    var ref: DatabaseReference!
    
    // MARK: - UIViewController LifeCycle Callback
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.ref = Database.database().reference()
        
        let userId = Auth.auth().currentUser?.uid
        
        guard let unwrappedUserId = userId else {
            return
        }
        
        ref.child("users").child(unwrappedUserId).child("families").observeSingleEvent(of: .value, with: {(snapshot) in
            let value = snapshot.value as? NSDictionary
            let familyId = value?.allKeys.first // User can belong to only one family.
            if let familyId = familyId {
                UserDefaults.standard.register(defaults: [UserDefaultsKey.FamilyId.rawValue: familyId])
            }
        }) { (error) in
            print(error.localizedDescription)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let indexPathForSelectedRow = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPathForSelectedRow, animated: true)
        }
        
        let realm = try! Realm()
        let results = realm.objects(Baby.self)
        
        token = results.observe { _ in
            self.tableView.reloadData()
        }
        
        babies = []
        for result in results {
            babies.append(result)
        }
        
        sections[0].cells = []
        sections[1].cells = []
        
        for baby in babies {
            let name = baby.name
            
            let f = DateFormatter()
            f.locale = Locale(identifier: "ja_JP")
            f.dateStyle = .long
            f.timeStyle = .none
            let born = f.string(from: baby.born) + "生まれ"
            
            sections[0].cells.append((label1: name, label2: born))
            sections[1].cells.append((label1: name, label2: born))
        }
        
        sections[1].cells.append((label1: "赤ちゃん追加", label2: ""))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let unwrappedToken = self.token {
            unwrappedToken.invalidate()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.ref.removeAllObservers() // TODO: Is it correct to remove all observers here?
    }
    
    
    
    
    // MARK: - UITableViewDateSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].cells.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell!
        let section = indexPath.section
        let row = indexPath.row
        switch section {
        case 0:
            cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            let label1 = cell.viewWithTag(1) as! UILabel
            label1.text = sections[section].cells[row].label1
            let label2 = cell.viewWithTag(2) as! UILabel
            label2.text = sections[section].cells[row].label2
            cell.accessoryType = isSelected(babies[row].id) ? .checkmark : .none

        case 1:
            cell = tableView.dequeueReusableCell(withIdentifier: "Cell2", for: indexPath)
            let label1 = cell.viewWithTag(1) as! UILabel
            label1.text = sections[section].cells[row].label1
            let label2 = cell.viewWithTag(2) as! UILabel
            label2.text = sections[section].cells[row].label2
            
        case 2:
            cell = tableView.dequeueReusableCell(withIdentifier: "ShareCell", for: indexPath)
            let label = cell.viewWithTag(1) as! UILabel
            label.text = sections[section].cells[row].label1

        default:
            cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
        }

        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].header
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = indexPath.section
        let row = indexPath.row
        
        switch section {
        case 0:
            if (!isSelected(babies[row].id)) {
                for row in 0..<sections[0].cells.count {
                    let cell = tableView.cellForRow(at: IndexPath(row: row, section: 0))!
                    cell.accessoryType = .none
                }
            
                let selectedCell = tableView.cellForRow(at: indexPath)!
                selectedCell.accessoryType = .checkmark
            
                select(babies[row].id)
            }
            
            tableView.deselectRow(at: indexPath, animated: true)
            
        case 1:
            switch row {
            case sections[1].cells.count - 1:
                // to AddBabyScreen
                let storyboard: UIStoryboard = self.storyboard!
                let editBabyViewController = storyboard.instantiateViewController(withIdentifier: "EditBabyViewController") as! EditBabyViewController
                editBabyViewController.baby = nil
                self.present(editBabyViewController, animated: true, completion: nil)
            
            default:
                // to EditBabyScreen
                let storyboard: UIStoryboard = self.storyboard!
                let editBabyViewController = storyboard.instantiateViewController(withIdentifier: "EditBabyViewController") as! EditBabyViewController
                editBabyViewController.baby = babies[row]
                self.present(editBabyViewController, animated: true, completion: nil)
            }
        
        case 2:
            switch row {
            case 0:
                createFamily()
            case 1:
                addFamily()
            case 2:
                joinFamily()
            case 3:
                deleteFamilyData()
            default:
                break
            }
            
            if let indexPathForSelectedRow = tableView.indexPathForSelectedRow {
                tableView.deselectRow(at: indexPathForSelectedRow, animated: true)
            }
        
        default:
            break
        }
    }
    
    
    // MARK: - Utility
    func isSelected(_ babyId: String) -> Bool {
        let currentBabyId = UserDefaults.standard.object(forKey: UserDefaultsKey.BabyId.rawValue) as? String
        if let unwrappedCurrentBabyId = currentBabyId {
            return unwrappedCurrentBabyId == babyId
        } else {
            let firstBabyId = babies.first!.id
            select(firstBabyId)
            return firstBabyId == babyId
        }
    }
    
    func select(_ babyId: String) {
        let userDefaults = UserDefaults.standard
        userDefaults.register(defaults: [UserDefaultsKey.BabyId.rawValue: babyId])
    }
    
    func createFamily() {
        let userDefaultsFamilyId = UserDefaults.standard.object(forKey: UserDefaultsKey.FamilyId.rawValue) as? String
        guard userDefaultsFamilyId == nil || userDefaultsFamilyId! == "" else {
            showAlert(title: "ご注意", message: "すでに家族に加わっているため、新しい家族を作成できません。")
            return // return when userDefaultsFamilyId is nil or ""
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            showAlert(title: "ご注意", message: "家族を作成するにはログインしてください。")
            return
        }
        
        let userName = Auth.auth().currentUser?.displayName
        let familyId = UUID().description
        UserDefaults.standard.register(defaults: [UserDefaultsKey.FamilyId.rawValue: familyId])
        self.ref.child("users").child(userId).setValue(["name": userName!])
        self.ref.child("users").child(userId).child("families").setValue([familyId: true])
        
        let realm = try! Realm()
        let babies = realm.objects(Baby.self)
        for baby in babies {
            let records = realm.objects(Record.self).filter("babyId == %@", baby.id)
            for record in records {
                self.ref.child("families").child(familyId)
                    .child("babies").child(baby.id)
                    .child("records").child(record.id)
                    .setValue([
                        "commandId": record.commandId!,
                        "dateTime": record.dateTime!.timeIntervalSince1970,
                        "value1": record.value1 ?? "",
                        "value2": record.value2 ?? "",
                        "value3": record.value3 ?? "",
                        "value4": record.value4 ?? "",
                        "value5": record.value5 ?? ""])
            }
        }
    }
    
    func addFamily() {
        let familyId = UserDefaults.standard.object(forKey: UserDefaultsKey.FamilyId.rawValue) as? String
        guard let _ = familyId, familyId != "" else {
            showAlert(title: "ご注意", message: "他のユーザーを家族に加える前に、新しく家族を作成してください。")
            return
        }
        
        guard let _ = Auth.auth().currentUser?.uid else {
            showAlert(title: "ご注意", message: "家族を加わるにはログインしてください。")
            return
        }
        
        // create onetime password
        let passcode = String(format: "%06d", arc4random_uniform(1000000))
        let expirationDate = Date() + 60 * 5 // 5 minutes

        // save onetime password and expiration date
        self.ref.child("families").child(familyId!).child("passcode").setValue(["value": passcode, "expirationDate": expirationDate.timeIntervalSince1970])

        // display familyId and onetime password
        let storyboard: UIStoryboard = self.storyboard!
        let familyIdAndPasscodeViewController = storyboard.instantiateViewController(withIdentifier: "FamilyIdAndPasscodeViewController") as! FamilyIdAndPasscodeViewController
        familyIdAndPasscodeViewController.familyIdText = familyId
        familyIdAndPasscodeViewController.passcodeText = passcode
        self.present(familyIdAndPasscodeViewController, animated: true, completion: nil)
    }
    
    func joinFamily() {
        let userDefaultsFamilyId = UserDefaults.standard.object(forKey: UserDefaultsKey.FamilyId.rawValue) as? String
        guard userDefaultsFamilyId != nil || userDefaultsFamilyId != "" else {
            showAlert(title: "ご注意", message: "すでに家族に加わっているため、他の家族には加われません。")
            return // return when userDefaultsFamilyId is nil or ""
        }
        
        let storyboard: UIStoryboard = self.storyboard!
        let joinFamilyViewController = storyboard.instantiateViewController(withIdentifier: "JoinFamilyViewController") as! JoinFamilyViewController
        self.present(joinFamilyViewController, animated: true, completion: nil)
    }
    
    func deleteFamilyData() {
        let userDefaultsFamilyId = UserDefaults.standard.object(forKey: UserDefaultsKey.FamilyId.rawValue) as? String
        guard let _ = userDefaultsFamilyId, userDefaultsFamilyId! != "" else {
            showAlert(title: "ご注意", message: "どの家族にも加わっていないため、削除機能は利用できません。")
            return // return when userDefaultsFamilyId is nil or ""
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            showAlert(title: "ご注意", message: "家族を作成するにはログインしてください。")
            return
        }
        
        self.ref.child("families").child(userDefaultsFamilyId!).removeValue() {
            (error: Error?, ref: DatabaseReference) in
            if let error = error {
                self.showAlert(title: "エラー", message: "データの削除に失敗しました。：" + error.localizedDescription)
                
            } else {
                print("Succeed Joining")
            }
        }
        
        self.ref.child("users").child(userId).child("families").removeValue()
        UserDefaults.standard.register(defaults: [UserDefaultsKey.FamilyId.rawValue: ""]) // create UserDefaults
    }
    
    func showAlert(title: String, message: String) {
        let alert: UIAlertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        let action: UIAlertAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: {(action: UIAlertAction!) -> Void in
            // do nothing
        })
        alert.addAction(action)
        present(alert, animated: true, completion: nil) // display alert
    }
}

