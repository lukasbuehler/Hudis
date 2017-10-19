//
//  ViewController.swift
//  Hudis
//
//  Created by Lukas Bühler on 16.10.17.
//  Copyright © 2017 Lukas Bühler. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UITextFieldDelegate, XMLParserDelegate {

    // Text field
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var inputErrorText: UILabel!
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var loadingWheel: UIActivityIndicatorView!
   
    @IBOutlet weak var outerCardView: UIView!
    @IBOutlet weak var innerCardView: UIView!
    @IBOutlet weak var phoneNumberText: UILabel!
    @IBOutlet weak var holderNameText: UILabel!
    @IBOutlet weak var holderAddressText: UILabel!
    
    var phoneNumber = "";
    
    // For XML parsing
    var callers = [Caller]();
    var caller = Caller(phoneNumber: 41_00_000_00_00);
    var foundCharacters = "";
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.textField.delegate = self
        self.inputErrorText.text = "";
        
        // Shadow for card
        // add the shadow to the base view
        
        outerCardView.clipsToBounds = false
        outerCardView.layer.shadowColor = UIColor.black.cgColor
        outerCardView.layer.shadowOpacity = 1
        outerCardView.layer.shadowOffset = CGSize.zero
        outerCardView.layer.shadowRadius = 15
        outerCardView.layer.shadowPath = UIBezierPath(roundedRect: outerCardView.bounds, cornerRadius: 15).cgPath
        
        innerCardView.clipsToBounds = true
        innerCardView.layer.cornerRadius = 15
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // Hide keyboard when user touches outside keyboard
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    // Presses return key
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return (true)
    }

    @IBAction func searchButtonPressed() {
        
        // Phone number we are searching
        
        var tempNumber = textField.text!
        tempNumber = tempNumber.removeWhitespaces();
        tempNumber = tempNumber.replacingOccurrences(of: "\\_", with: "", options: NSString.CompareOptions.literal, range:nil)
        tempNumber = tempNumber.replacingOccurrences(of: "\\-", with: "", options: NSString.CompareOptions.literal, range:nil)
        self.phoneNumber = String(tempNumber);
        
        print(self.phoneNumber.replacingOccurrences(of: "\\d", with: "", options: NSString.CompareOptions.regularExpression, range:nil));
        if(self.phoneNumber.replacingOccurrences(of: "\\d", with: "", options: NSString.CompareOptions.regularExpression, range:nil) != "")
        {
            self.inputErrorText.text = "There are some weird symboles in there";
            print("Warning: Unknown symbols in input")
            return;
        }
        else
        {
            self.inputErrorText.text = "";
        }
        print("The phone number is: \(self.phoneNumber)");
        
        
        self.callers.removeAll();
        
        // UI
        self.view.endEditing(true);
        self.loadingWheel.startAnimating();
        
        
        let url = URL(string: "https://tel.search.ch/api/?tel=\(self.phoneNumber)") // tel isn't even in the api but it works anyway
        URLSession.shared.dataTask(with: url!, completionHandler: {
            (data, response, error) in
            if(error != nil){
                print("Error response from API")
                
                // UI
                DispatchQueue.main.async {
                    self.loadingWheel.stopAnimating();
                }
            }else{
                let parser = XMLParser(data: data!)
                parser.delegate = self
                if parser.parse() {
                    // Success, we could parse everything
                    
                    if(self.callers.count > 0)
                    {
                        DispatchQueue.main.async { // This is needed because we can't update the UI outside of the main thread.
                            self.loadingWheel.stopAnimating();
                            
                            // Set the labels
                            self.holderNameText.text = self.callers[0].name;
                            self.phoneNumberText.text = self.getPhoneNumberStringFromInt(int: self.callers[0].phone);
                            
                            // Show the cards
                        }
                    }
                    else
                    {
                        print("No caller found for \(self.phoneNumber)")
                        DispatchQueue.main.async {
                            self.loadingWheel.stopAnimating();
                            self.holderNameText.text = "No caller found";
                            self.phoneNumberText = "";
                        }
                    }
                    
                }
            }
        }).resume()
    }
    
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
    }
    
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        self.foundCharacters += string;
    }
    
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "title" {
            self.caller.name = self.foundCharacters.substring(from: self.foundCharacters.index(self.foundCharacters.startIndex, offsetBy: 5)); // 1 for return and 4 for tab spaces
            if(self.caller.name == "Callcenter")
            {
                self.caller.isBlocked = true;
            }
        }
        
        
        if elementName == "content" {
            
            // Find phone number
            self.caller.phone = getPhoneNumberIntFromString(string: getPhoneNumberStringFromContextString(string: self.foundCharacters));
        }
        
        if elementName == "entry" {
            let tempCaller = Caller(phoneNumber: self.caller.phone);
            tempCaller.name = self.caller.name;
            
            self.callers.append(tempCaller);
            self.caller = Caller(phoneNumber: 41_00_000_00_00);
        }
        
        
        self.foundCharacters = ""
    }
    
    
    func parserDidEndDocument(_ parser: XMLParser) {
        // Maybe do something, but I handle it on the main thread
    }
    
    
    func matches(for regex: String, in text: String) -> [String] {
        
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            return results.map {
                String(text[Range($0.range, in: text)!])
            }
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
    
    
    func getPhoneNumberStringFromContextString(string: String) -> String {
        let str =  string.substring(from: string.index(string.index(of: "/")!, offsetBy: 4))
        
        return str;
    }
    
    func getPhoneNumberIntFromString(string: String) -> UInt64 {
        // This is not working for stuff like 117, 1818 and so on
        
        // Format string
        var str = string.removeWhitespaces()
        str = str.substring(from: string.index(string.startIndex, offsetBy: 1))
        str = "41"+str;
        
        // Convert to UInt64
        print(str);
        return UInt64(str)!;
    }
    
    func getPhoneNumberStringFromInt(int: UInt64) -> String {
        return String(int); // Not good enough but works for now.
    }
}

extension String {
    func removeWhitespaces() -> String {
        return components(separatedBy: .whitespaces).joined()
    }
}
