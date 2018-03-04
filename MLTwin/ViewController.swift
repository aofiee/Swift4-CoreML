//
//  ViewController.swift
//  MLTwin
//
//  Created by SkullTree on 4/3/2561 BE.
//  Copyright © 2561 SkullTree. All rights reserved.
//

import UIKit
import AVFoundation
import Photos
import CoreML
import Vision

class ViewController: UIViewController {
    @IBOutlet weak var previewView: UIView!
    
    var captureSession: AVCaptureSession?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var capturePhotoOutput: AVCapturePhotoOutput?
    var gender = ""
    var age = ""
    @IBOutlet weak var resultLabel: UILabel!
    let modelGender = GenderNet()
    let modelAge = AgeNet()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initViewFinder()
    }
    func initViewFinder(){
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .back) else {
            fatalError("No vidoe device")
        }
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            captureSession = AVCaptureSession()
            captureSession?.addInput(input)
            capturePhotoOutput = AVCapturePhotoOutput()
            capturePhotoOutput?.isHighResolutionCaptureEnabled = true
            captureSession?.addOutput(capturePhotoOutput!)
            let captureMetadataOutput = AVCaptureMetadataOutput()
            captureSession?.addOutput(captureMetadataOutput)
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
            videoPreviewLayer?.frame = view.layer.bounds
            previewView.layer.addSublayer(videoPreviewLayer!)
            captureSession?.startRunning()
        } catch {
            print(error)
            return
        }
    }
    func resGender(request: VNRequest, errpr: Error?) {
        gender = ""
        guard let results = request.results as? [VNClassificationObservation] else {
            fatalError("no result")
        }
        var bestPrediction = ""
        var bestConfidence: VNConfidence = 0
        for classification in results {
            if(classification.confidence >  bestConfidence) {
                bestConfidence = classification.confidence
                bestPrediction = classification.identifier
            }
        }
        print("\(bestPrediction) \(bestConfidence)")
        gender = bestPrediction
        self.resultLabel.text = "Gender: "+gender+" Age: "+age
    }
    
    func resAge(request: VNRequest, errpr: Error?) {
        age = ""
        guard let results = request.results as? [VNClassificationObservation] else {
            fatalError("no result")
        }
        var bestPrediction = ""
        var bestConfidence: VNConfidence = 0
        for classification in results {
            if(classification.confidence >  bestConfidence) {
                bestConfidence = classification.confidence
                bestPrediction = classification.identifier
            }
        }
        print("\(bestPrediction) \(bestConfidence)")
        age = bestPrediction
        self.resultLabel.text = "Gender: "+gender+" Age: "+age
    }
    @IBAction func didTakePhoto(sender: UIButton) {
        self.resultLabel.text = "Loading..."
        guard let capturePhotoOutput = self.capturePhotoOutput else { return }
        let photoSettings = AVCapturePhotoSettings()
        photoSettings.isAutoStillImageStabilizationEnabled = true
        photoSettings.isHighResolutionPhotoEnabled = true
        photoSettings.flashMode = .auto
        capturePhotoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    override func viewDidLayoutSubviews() {
        videoPreviewLayer?.frame = view.bounds
        if let previewLayer = videoPreviewLayer ,(previewLayer.connection?.isVideoOrientationSupported)! {
            previewLayer.connection?.videoOrientation = UIApplication.shared.statusBarOrientation.videoOrientation ?? .portrait
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

extension ViewController : AVCapturePhotoCaptureDelegate {
    @available(iOS 11.0, *)
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            print("Error capturing: \(String(describing: error))")
            return
        }
        guard let imageData = photo.fileDataRepresentation() else {
            return
        }
        let capturedImage = UIImage.init(data: imageData , scale: 1.0)
        if let image = capturedImage {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            
            let modelG = try! VNCoreMLModel(for: modelGender.model)
            let modelA = try! VNCoreMLModel(for: modelAge.model)
            
            let handlerGender = VNImageRequestHandler(cgImage: image.cgImage!, options: [:])
            let handlerAge = VNImageRequestHandler(cgImage: image.cgImage!, options: [:])
            let requestGender = VNCoreMLRequest(model: modelG, completionHandler: resGender)
            let requestAge = VNCoreMLRequest(model: modelA, completionHandler: resAge)
            try! handlerGender.perform([requestGender])
            try! handlerAge.perform([requestAge])
        }
    }
}

extension ViewController : AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ captureOutput: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        _ = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
    }
}

extension UIInterfaceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeRight: return .landscapeRight
        case .landscapeLeft: return .landscapeLeft
        case .portrait: return .portrait
        default: return nil
        }
    }
}
