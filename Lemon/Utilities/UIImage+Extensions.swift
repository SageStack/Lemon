//
//  UIImage+Extensions.swift
//  Lemon
//
//  Created by Shaluka Hewapatha on 06/01/2026.
//

import UIKit

extension UIImage {
    
    /// Compresses the image for optimized network upload.
    /// Resizes the image to a max dimension (e.g. 1024px) and compresses quality (e.g. 0.6).
    func compressedForUpload(maxDimension: CGFloat = 1024, quality: CGFloat = 0.6) -> Data? {
        let resized = self.resized(toMaxDimension: maxDimension)
        return resized.jpegData(compressionQuality: quality)
    }
    
    private func resized(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let width = self.size.width
        let height = self.size.height
        
        if width <= maxDimension && height <= maxDimension {
            return self
        }
        
        let aspectRatio = width / height
        var newWidth: CGFloat
        var newHeight: CGFloat
        
        if width > height {
            newWidth = maxDimension
            newHeight = maxDimension / aspectRatio
        } else {
            newHeight = maxDimension
            newWidth = maxDimension * aspectRatio
        }
        
        let size = CGSize(width: newWidth, height: newHeight)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        self.draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? self
    }
}
