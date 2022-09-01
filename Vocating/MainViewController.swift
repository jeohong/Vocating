//
//  MainViewController.swift
//  Vocating
//
//  Created by Hong jeongmin on 2022/09/01.
//

import UIKit

class MainViewController: UIViewController {
    //MARK: - Properties
    private let audioButton: UIButton = {
        let button = UIButton()
        button.setTitle("말하기!", for: .normal)
        
        return button
    }()
    
    //MARK: - LifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
    }
    //MARK: - Selectors
    //MARK: - Helpers
    func configureUI() {
        //레이아웃 구성
        self.view?.addSubview(audioButton)
        audioButton.translatesAutoresizingMaskIntoConstraints = false
        audioButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        audioButton.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
    }
}
