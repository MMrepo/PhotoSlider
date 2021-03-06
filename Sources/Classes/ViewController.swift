//
//  ViewController.swift
//
//  Created by nakajijapan on 3/28/15.
//  Copyright (c) 2015 net.nakajijapan. All rights reserved.
//

import UIKit

@objc public protocol PhotoSliderDelegate:NSObjectProtocol {
    optional func photoSliderControllerWillDismiss(viewController: PhotoSlider.ViewController)
    optional func photoSliderControllerDidDismiss(viewController: PhotoSlider.ViewController)
}

enum PhotoSliderControllerScrollMode:UInt {
    case None = 0, Vertical, Horizontal, Rotating
}

enum PhotoSliderControllerUsingImageType:UInt {
    case None = 0, URL, Image, Photo
}

public class ViewController:UIViewController, UIScrollViewDelegate, PhotoSliderImageViewDelegate, ZoomingAnimationControllerTransitioning {
    
    var scrollView:UIScrollView!
    
    var imageURLs:Array<NSURL>?
    var images:Array<UIImage>?
    var photos:Array<PhotoSlider.Photo>?
    var usingImageType = PhotoSliderControllerUsingImageType.None
    var backgroundView:UIView!
    var effectView:UIVisualEffectView!
    var closeButton:UIButton?
    var shareButton:UIButton?
    
    var emailButton:UIButton?
    var callButton:UIButton?
    
    var scrollMode:PhotoSliderControllerScrollMode = .None
    var scrollInitalized = false
    var closeAnimating = false
    var imageViews = Array<PhotoSlider.ImageView>()
    var previousPage = 0
    var captionLabel = UILabel(frame: CGRectZero)
    public var shareButtonImage:UIImage?
    public var shareButtonAction: (() -> ())?
    public var emailButtonAction: (() -> ())?
    public var callButtonAction: (() -> ())?
    
    public var emailButtonColor:UIColor?
    public var callButtonColor:UIColor?
    
    public var delegate: PhotoSliderDelegate? = nil
    public var visiblePageControl = true
    public var visibleCloseButton = true
    public var visibleShareButton = true
    public var visibleEmailButton = true
    public var visibleCallButton = true
    public var isPresented = false
    public var shouldShowEmailForm = false
    
    public var currentPage = 0 {
        didSet {
            updatePageLabel(currentPage + 1)
        }
    }
    
    public var pageControl = UIPageControl()
    public var backgroundViewColor = UIColor.blackColor()
    public var captionTextColor = UIColor.whiteColor()
    
    var pageLabel:UILabel?
    var visiblePageLabel = true
    
    public init(imageURLs:Array<NSURL>) {
        super.init(nibName: nil, bundle: nil)
        self.imageURLs = imageURLs
        self.usingImageType = .URL
    }
    
    public init(images:Array<UIImage>) {
        super.init(nibName: nil, bundle: nil)
        self.images = images
        self.usingImageType = .Image
    }
    
    public init(photos:Array<PhotoSlider.Photo>) {
        super.init(nibName: nil, bundle: nil)
        self.photos = photos
        self.usingImageType = .Photo
    }
    
    required public init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }
    
    override public func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return .AllButUpsideDown
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "rotate:", name:UIApplicationDidChangeStatusBarFrameNotification, object: nil)
        
        
        self.view.frame = UIScreen.mainScreen().bounds
        self.view.backgroundColor = UIColor.clearColor()
        
        self.backgroundView = UIView(frame: self.view.bounds)
        self.backgroundView.backgroundColor = self.backgroundViewColor
        
        if floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1 {
            self.view.addSubview(self.backgroundView)
        } else {
            self.effectView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffectStyle.Dark))
            self.effectView.frame = self.view.bounds
            self.view.addSubview(self.effectView)
            self.effectView.addSubview(self.backgroundView)
        }
        
        // scrollview setting for Item
        self.scrollView = UIScrollView(frame: CGRectMake(0, 0, self.view.bounds.width, self.view.bounds.height))
        self.scrollView.pagingEnabled = true
        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.delegate = self
        self.scrollView.clipsToBounds = false
        self.scrollView.alwaysBounceHorizontal = true
        self.scrollView.alwaysBounceVertical = true
        self.scrollView.scrollEnabled = true
        self.scrollView.accessibilityLabel = "PhotoSliderScrollView"
        self.view.addSubview(self.scrollView)
        self.layoutScrollView()
        
        self.scrollView.contentSize = CGSizeMake(
            CGRectGetWidth(self.view.bounds) * CGFloat(self.imageResources()!.count),
            CGRectGetHeight(self.view.bounds) * 3.0
        )
        
        let width = CGRectGetWidth(self.view.bounds)
        let height = CGRectGetHeight(self.view.bounds)
        var frame = self.view.bounds
        frame.origin.y = height
        for imageResource in self.imageResources()! {
            
            let imageView:PhotoSlider.ImageView = PhotoSlider.ImageView(frame: frame)
            imageView.delegate = self
            self.scrollView.addSubview(imageView)
            
            if imageResource.dynamicType === NSURL.self {
                imageView.loadImage(imageResource as! NSURL)
            } else if imageResource.dynamicType === UIImage.self {
                imageView.setImage(imageResource as! UIImage)
            } else {
                let photo = imageResource as! PhotoSlider.Photo
                if photo.imageURL != nil {
                    imageView.loadImage(photo.imageURL!)
                } else {
                    imageView.setImage(photo.image!)
                }
            }
            
            frame.origin.x += width
            
            imageViews.append(imageView)
        }
        
        // Page Control
        if self.visiblePageControl {
            self.pageControl.frame = CGRectZero
            self.pageControl.numberOfPages = self.imageResources()!.count
            self.pageControl.userInteractionEnabled = false
            self.view.addSubview(self.pageControl)
            self.layoutPageControl()
        }
        
        // Close Button
        if self.visibleCloseButton {
            self.closeButton = UIButton(frame: CGRectZero)
            let imagePath = self.resourceBundle().pathForResource("PhotoSliderClose", ofType: "png")
            self.closeButton!.setImage(UIImage(contentsOfFile: imagePath!), forState: UIControlState.Normal)
            self.closeButton!.addTarget(self, action: "closeButtonDidTap:", forControlEvents: UIControlEvents.TouchUpInside)
            self.closeButton!.imageView?.contentMode = UIViewContentMode.Center
            self.view.addSubview(self.closeButton!)
            self.layoutCloseButton()
        }
        
        // Share Button
        if self.visibleShareButton {
            self.shareButton = UIButton(type: .System)
            self.shareButton!.setImage(shareButtonImage, forState: UIControlState.Normal)
            self.shareButton!.addTarget(self, action: "shareButtonDidTap:", forControlEvents: UIControlEvents.TouchUpInside)
            self.shareButton!.imageView?.contentMode = UIViewContentMode.Center
            self.shareButton!.tintColor = UIColor.whiteColor()
            self.view.addSubview(self.shareButton!)
            self.layoutShareButton()
        }
        
        // Caption
        self.captionLabel.textColor = self.captionTextColor
        self.captionLabel.numberOfLines = 3
        self.view.addSubview(self.captionLabel)
        self.layoutCaptionLabel()
        
        self.updateCaption()
        self.setNeedsStatusBarAppearanceUpdate()
        
        // Page Label
        if self.visiblePageLabel {
            self.pageLabel = UILabel(frame: CGRectZero)
            self.pageLabel?.textColor = UIColor.whiteColor()
            self.pageLabel?.font = UIFont (name: "OpenSans-Italic", size: 16.0)
            
            self.view.addSubview(self.pageLabel!)
            self.layoutPageLabel()
        }
        
        // SingleTapGesture
        let singleTapGesture = UITapGestureRecognizer(target: self, action: "didSingleTap:")
        singleTapGesture.numberOfTapsRequired = 1
        self.scrollView.addGestureRecognizer(singleTapGesture)
        
        self.emailButton = UIButton(frame: CGRectZero)
        self.emailButton?.setTitle("Email", forState: .Normal)
        self.emailButton?.titleLabel?.font = UIFont (name: "OpenSans-Bold", size: 13.0)
        self.emailButton?.backgroundColor = self.emailButtonColor
        self.emailButton!.addTarget(self, action: "emailButtonDidTap:", forControlEvents: UIControlEvents.TouchUpInside)
        
        self.callButton = UIButton(frame: CGRectZero)
        self.callButton?.setTitle("Call", forState: .Normal)
        self.callButton?.titleLabel?.font = UIFont (name: "OpenSans-Bold", size: 13.0)
        self.callButton?.backgroundColor = self.callButtonColor
        self.callButton!.addTarget(self, action: "callButtonDidTap:", forControlEvents: UIControlEvents.TouchUpInside)
        
        if visibleCallButton && visibleEmailButton {
            // show both
            self.view.addSubview(self.emailButton!)
            self.view.addSubview(self.callButton!)
            self.layoutEmailAndCallButton()
        } else if visibleCallButton {
            self.view.addSubview(self.callButton!)
            self.layoutCallButton()
        } else if visibleEmailButton {
            self.view.addSubview(self.emailButton!)
            self.layoutEmailButton()
        } else {
            //Hide both
        }
        self.view.layoutIfNeeded()
        
    }
    
    override public func viewWillAppear(animated: Bool) {
        self.scrollView.contentOffset = CGPointMake(self.scrollView.bounds.width * CGFloat(self.currentPage), self.scrollView.bounds.height)
        self.scrollInitalized = true
        
        //        isPresented = true
    }
    
    var originalWindow:UIWindow?
    var originalRootViewController:UIViewController?
    var window:UIWindow?
    
    //    static var photoSlider:ViewController?
    
    public override func viewDidAppear(animated: Bool) {
        
        originalWindow = UIApplication.sharedApplication().keyWindow
        originalRootViewController = originalWindow?.rootViewController
        originalWindow?.rootViewController = nil
        self.removeFromParentViewController()
        self.view.removeFromSuperview()
        window = UIWindow(frame:UIScreen.mainScreen().bounds)
        window?.tag = 666
        window?.rootViewController = self
        window?.hidden = false
        window?.makeKeyAndVisible()
        //        window?.addSubview(ViewController.photoSlider!.view)
        
        print("AAA: \(window?.rootViewController)")
        
        let delay = 0.1 * Double(NSEC_PER_SEC)
        let time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
        dispatch_after(time, dispatch_get_main_queue()) {
            self.originalWindow?.hidden = true
        }
        
        super.viewDidAppear(animated)
        isPresented = true
    }
    
    
    override public func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    //    override public func viewDidDisappear(animated: Bool) {
    //        super.viewDidDisappear(animated)
    //        window = nil
    //        originalWindow?.hidden = false
    //        originalWindow?.makeKeyWindow()
    //    }
    
    public override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    public override func shouldAutorotate() -> Bool {
        if self.scrollMode == .None {
            return true
        }
        else {
            return false
        }
    }
    
    public func currentAllowedOrientation() -> UIInterfaceOrientationMask {
        
        if UIApplication.sharedApplication().statusBarOrientation.isLandscape {
            print("landscape: \(self.scrollView.scrollEnabled)")
            if self.scrollView.scrollEnabled && self.scrollMode == .None {
                return .All
            }
            else {
                return .Landscape
            }
        }
        
        if UIApplication.sharedApplication().statusBarOrientation.isPortrait {
            print("protrait: \(self.scrollView.scrollEnabled)")
            if self.scrollView.scrollEnabled && self.scrollMode == .None {
                return .All
            }
            else {
                return .Portrait
            }
        }
        
        return .All
    }
    // MARK: - Constraints
    
    func layoutScrollView() {
        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        let views = ["scrollView": self.scrollView]
        let constraintVertical   = NSLayoutConstraint.constraintsWithVisualFormat("V:|[scrollView]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views)
        let constraintHorizontal = NSLayoutConstraint.constraintsWithVisualFormat("H:|[scrollView]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views)
        self.view.addConstraints(constraintVertical)
        self.view.addConstraints(constraintHorizontal)
    }
    
    func layoutCloseButton() {
        self.closeButton!.translatesAutoresizingMaskIntoConstraints = false
        
        let views = ["closeButton": self.closeButton!]
        let constraintVertical   = NSLayoutConstraint.constraintsWithVisualFormat("V:|[closeButton(52)]", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views)
        let constraintHorizontal = NSLayoutConstraint.constraintsWithVisualFormat("H:|[closeButton(52)]", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views)
        self.view.addConstraints(constraintVertical)
        self.view.addConstraints(constraintHorizontal)
    }
    
    func layoutShareButton() {
        self.shareButton!.translatesAutoresizingMaskIntoConstraints = false
        
        let views = ["shareButton": self.shareButton!]
        let constraintVertical   = NSLayoutConstraint.constraintsWithVisualFormat("V:|[shareButton(52)]", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views)
        let constraintHorizontal = NSLayoutConstraint.constraintsWithVisualFormat("H:[shareButton(52)]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views)
        self.view.addConstraints(constraintVertical)
        self.view.addConstraints(constraintHorizontal)
    }
    
    func layoutPageControl() {
        self.pageControl.translatesAutoresizingMaskIntoConstraints = false
        
        let views = ["pageControl": self.pageControl]
        let constraintVertical = NSLayoutConstraint.constraintsWithVisualFormat("V:[pageControl]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views)
        let constraintCenterX  = NSLayoutConstraint.constraintsWithVisualFormat("H:|[pageControl]|", options: NSLayoutFormatOptions.AlignAllCenterX, metrics: nil, views: views)
        self.view.addConstraints(constraintVertical)
        self.view.addConstraints(constraintCenterX)
    }
    
    func layoutCaptionLabel() {
        self.captionLabel.translatesAutoresizingMaskIntoConstraints = false
        let views = ["captionLabel": self.captionLabel]
        let constraintVertical   = NSLayoutConstraint.constraintsWithVisualFormat(
            "V:[captionLabel]-32-|",
            options: NSLayoutFormatOptions(rawValue: 0),
            metrics: nil,
            views: views
        )
        let constraintHorizontal = NSLayoutConstraint.constraintsWithVisualFormat(
            "H:|-16-[captionLabel]-16-|",
            options: NSLayoutFormatOptions(rawValue: 0),
            metrics: nil,
            views: views
        )
        self.view.addConstraints(constraintVertical)
        self.view.addConstraints(constraintHorizontal)
    }
    
    func layoutPageLabel() {
        self.pageLabel!.translatesAutoresizingMaskIntoConstraints = false
        
        let views = ["pageLabel": self.pageLabel!, "superview": self.view]
        let constraintVertical = NSLayoutConstraint.constraintsWithVisualFormat("V:|-16-[pageLabel]", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views)
        
        let constraintCenterX = NSLayoutConstraint.constraintsWithVisualFormat(
            "V:[superview]-(<=1)-[pageLabel]",
            options: NSLayoutFormatOptions.AlignAllCenterX,
            metrics: nil,
            views: views)
        
        self.view.addConstraints(constraintVertical)
        self.view.addConstraints(constraintCenterX)
    }
    
    func layoutEmailAndCallButton() {
        self.emailButton!.translatesAutoresizingMaskIntoConstraints = false
        self.callButton!.translatesAutoresizingMaskIntoConstraints = false
        
        let views = ["emailButton": self.emailButton!,"callButton": self.callButton!, "superview": self.view]
        let constraintEmailVertical = NSLayoutConstraint.constraintsWithVisualFormat("V:[emailButton(50)]-0-|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views)
        
        let constraintCenterX  = NSLayoutConstraint.constraintsWithVisualFormat("H:|-0-[callButton(==emailButton)][emailButton]-0-|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views)
        
        let constraintCallVertical = NSLayoutConstraint.constraintsWithVisualFormat("V:[callButton(50)]-0-|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views)
        
        self.view.addConstraints(constraintEmailVertical)
        self.view.addConstraints(constraintCallVertical)
        
        self.view.addConstraints(constraintCenterX)
    }
    
    func layoutEmailButton() {
        self.emailButton!.translatesAutoresizingMaskIntoConstraints = false
        
        let views = ["emailButton": self.emailButton!, "superview": self.view]
        let constraintVertical = NSLayoutConstraint.constraintsWithVisualFormat("V:[emailButton(50)]-0-|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views)
        
        let constraintCenterX  = NSLayoutConstraint.constraintsWithVisualFormat("H:|-0-[emailButton]-0-|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views)
        
        
        self.view.addConstraints(constraintVertical)
        self.view.addConstraints(constraintCenterX)
    }
    
    func layoutCallButton() {
        self.callButton!.translatesAutoresizingMaskIntoConstraints = false
        
        let views = ["callButton": self.callButton!, "superview": self.view]
        let constraintVertical = NSLayoutConstraint.constraintsWithVisualFormat("V:[callButton(50)]-0-|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views)
        
        let constraintCenterX  = NSLayoutConstraint.constraintsWithVisualFormat("H:|-0-[callButton]-0-|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views)
        
        
        self.view.addConstraints(constraintVertical)
        self.view.addConstraints(constraintCenterX)
    }
    
    // MARK: - UIScrollViewDelegate
    
    var scrollPreviewPoint = CGPointZero
    public func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        
        self.previousPage = self.currentPage
        
        self.scrollPreviewPoint = scrollView.contentOffset
        
    }
    
    public func scrollViewDidScroll(scrollView: UIScrollView) {
        if scrollInitalized == false {
            self.generateCurrentPage()
            return
        }
        
        let imageView = self.imageViews[self.currentPage]
        if imageView.scrollView.zoomScale > 1.0 {
            self.generateCurrentPage()
            self.scrollView.scrollEnabled = false
            return
        }
        
        if self.scrollMode == .Rotating {
            return
        }
        
        
        let offsetX = fabs(scrollView.contentOffset.x - self.scrollPreviewPoint.x)
        let offsetY = fabs(scrollView.contentOffset.y - self.scrollPreviewPoint.y)
        
        if self.scrollMode == .None {
            if (offsetY > offsetX) {
                self.scrollMode = .Vertical
            } else {
                self.scrollMode = .Horizontal
            }
        }
        
        if self.scrollMode == .Vertical {
            if UIApplication.sharedApplication().statusBarOrientation.isLandscape {
                scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x, y: scrollPreviewPoint.y)
            }
            
            let offsetHeight = fabs(scrollView.frame.size.height - scrollView.contentOffset.y)
            let alpha = 1.0 - ( fabs(offsetHeight) / (scrollView.frame.size.height / 2.0) )
            
            self.backgroundView.alpha = alpha
            
            var contentOffset = scrollView.contentOffset
            contentOffset.x = self.scrollPreviewPoint.x
            scrollView.contentOffset = contentOffset
            
            let screenHeight = UIScreen.mainScreen().bounds.size.height
            
            if self.scrollView.contentOffset.y > screenHeight * 1.4 {
                self.closePhotoSlider(true)
            } else if self.scrollView.contentOffset.y < screenHeight * 0.6  {
                self.closePhotoSlider(false)
            }
            
        } else if self.scrollMode == .Horizontal {
            var contentOffset = scrollView.contentOffset
            contentOffset.y = self.scrollPreviewPoint.y
            scrollView.contentOffset = contentOffset
        }
        
        // Update current page index.
        self.generateCurrentPage()
        
    }
    
    func generateCurrentPage() {
        
        var page = Int(round(scrollView.contentOffset.x / scrollView.frame.size.width))
        if page < 0 {
            page = 0
        } else if page >= self.imageResources()?.count {
            page = self.imageResources()!.count - 1;
        }
        
        self.currentPage = page
        
        if self.visiblePageControl {
            self.pageControl.currentPage = self.currentPage
        }
        
    }
    
    public func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        
        if self.scrollMode == .Vertical {
            
            let velocity = scrollView.panGestureRecognizer.velocityInView(scrollView)
            if velocity.y < -500 {
                self.scrollView.frame = scrollView.frame
                self.closePhotoSlider(true)
            } else if velocity.y > 500 {
                self.scrollView.frame = scrollView.frame
                self.closePhotoSlider(false)
            }
        }
    }
    
    func closePhotoSlider(up:Bool) {
        
        
        if UIApplication.sharedApplication().statusBarOrientation.isLandscape {
            return
        }
        print("landscape? \(UIApplication.sharedApplication().statusBarOrientation.isLandscape)")
        if self.closeAnimating == true {
            return
        }
        self.closeAnimating = true
        
        let screenHeight = UIScreen.mainScreen().bounds.size.height
        let screenWidth = UIScreen.mainScreen().bounds.size.width
        var movedHeight = CGFloat(0)
        
        self.delegate?.photoSliderControllerWillDismiss?(self)
        
        if up {
            movedHeight = -screenHeight
        } else {
            movedHeight = screenHeight
        }
        
        isPresented = false
        
        UIDevice.currentDevice().setValue(NSNumber(integer: UIInterfaceOrientation.Portrait.rawValue), forKey: "orientation")
        
        
        UIView.animateWithDuration(
            0.4,
            delay: 0,
            options: UIViewAnimationOptions.CurveEaseOut,
            animations: { () -> Void in
                self.scrollView.frame = CGRectMake(0, movedHeight, screenWidth, screenHeight)
                self.backgroundView.alpha = 0.0
                self.closeButton?.alpha = 0.0
                self.captionLabel.alpha = 0.0
                self.callButton?.alpha = 0.0
                self.emailButton?.alpha = 0.0
                self.view.alpha = 0.0
            },
            completion: {(result) -> Void in
                self.dissmissViewControllerAnimated(false)
                self.closeAnimating = false
            }
        )
    }
    
    public func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        
        if self.previousPage != self.currentPage {
            
            // If page index has changed - reset zoom scale for previous image.
            let imageView = self.imageViews[self.previousPage]
            imageView.scrollView.zoomScale = imageView.scrollView.minimumZoomScale
            
            // Show Caption Label
            self.updateCaption()
            
        }
        
        self.scrollMode = .None
        
    }
    
    // MARK: - Button Actions
    
    func closeButtonDidTap(sender:UIButton) {
        
        dismissPhotoSlider()
        
    }
    
    func shareButtonDidTap(sender:UIButton) {
        shareButtonAction?()
    }
    
    func emailButtonDidTap(sender:UIButton) {
        emailButtonAction?()
    }
    
    func callButtonDidTap(sender:UIButton) {
        callButtonAction?()
    }
    
    
    // MARK: - PhotoSliderImageViewDelegate
    
    func photoSliderImageViewDidEndZooming(viewController: PhotoSlider.ImageView, atScale scale: CGFloat) {
        if scale <= 1.0 {
            self.scrollView.scrollEnabled = true
            
            UIView.animateWithDuration(0.05, delay: 0.0, options: UIViewAnimationOptions.CurveLinear, animations: { () -> Void in
                self.closeButton?.alpha = 1.0
                self.shareButton?.alpha = 1.0
                self.captionLabel.alpha = 1.0
                if self.visiblePageControl {
                    self.pageControl.alpha = 1.0
                }
                if self.visiblePageLabel {
                    self.pageLabel?.alpha = 1.0
                }
                
                if self.visibleCallButton {
                    self.callButton?.alpha = 1.0
                }
                if self.visibleEmailButton {
                    self.emailButton?.alpha = 1.0
                }
                }, completion: nil)
            
        } else {
            self.scrollView.scrollEnabled = false
            
            UIView.animateWithDuration(0.05, delay: 0.0, options: UIViewAnimationOptions.CurveLinear, animations: { () -> Void in
                self.closeButton?.alpha = 0.0
                self.shareButton?.alpha = 0.0
                self.captionLabel.alpha = 0.0
                if self.visiblePageControl {
                    self.pageControl.alpha = 0.0
                }
                if self.visiblePageLabel {
                    self.pageLabel?.alpha = 0.0
                }
                if self.visibleCallButton {
                    self.callButton?.alpha = 0.0
                }
                if self.visibleEmailButton {
                    self.emailButton?.alpha = 0.0
                }
                }, completion: nil)
        }
    }
    
    // MARK: - Private Methods
    func updatePageLabel(pageNumber:Int) {
        self.pageLabel?.text = "\(pageNumber) of \(self.imageResources()!.count)"
    }
    
    
    func dissmissViewControllerAnimated(animated:Bool) {
        
        //        ViewController.photoSlider = nil
        originalWindow?.rootViewController = originalRootViewController
        originalWindow?.addSubview(self.view)
        originalWindow?.hidden = false
        originalWindow?.makeKeyWindow()
        window = nil
        
        self.dismissViewControllerAnimated(animated, completion: { () -> Void in
            
            self.delegate?.photoSliderControllerDidDismiss?(self)
            
        })
    }
    
    func resourceBundle() -> NSBundle {
        
        let bundlePath = NSBundle.mainBundle().pathForResource(
            "PhotoSlider",
            ofType: "bundle",
            inDirectory: "Frameworks/PhotoSlider.framework"
        )
        
        if bundlePath != nil {
            return NSBundle(path: bundlePath!)!
        }
        
        return NSBundle(forClass: self.dynamicType)
        
    }
    
    // MARK: - UITraitEnvironment
    
    func rotate(notification:NSNotification? = nil) {
        
        self.scrollMode = .Rotating
        
        let contentViewBounds = UIScreen.mainScreen().bounds
        let height = contentViewBounds.height
        // Background View
        self.backgroundView.frame = contentViewBounds
        if floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_7_1 {
            self.effectView.frame = contentViewBounds
        }
        
        // Scroll View
        self.scrollView.contentSize = CGSizeMake(
            contentViewBounds.width * CGFloat(self.imageResources()!.count),
            contentViewBounds.height * 3.0
        )
        self.scrollView.frame = contentViewBounds
        
        // ImageViews
        var frame = CGRect(x: 0.0, y: contentViewBounds.height, width: contentViewBounds.width, height: contentViewBounds.height)
        for i in 0..<self.scrollView.subviews.count {
            
            let imageView = self.scrollView.subviews[i] as! PhotoSlider.ImageView
            
            imageView.frame = frame
            frame.origin.x += contentViewBounds.size.width
            imageView.scrollView.frame = contentViewBounds
            
            imageView.layoutImageView()
            
        }
        
        self.scrollView.contentOffset = CGPointMake(CGFloat(self.currentPage) * contentViewBounds.width, height)
        
        self.scrollMode = .None
    }
    
    public override func traitCollectionDidChange(previousTraitCollection: UITraitCollection?) {
        
        if previousTraitCollection == nil {
            return
        }
        
        //       rotate()
    }
    
    // MARK: - ZoomingAnimationControllerTransitioning
    
    public func transitionSourceImageView() -> UIImageView {
        let zoomingImageView = self.imageViews[self.currentPage]
        zoomingImageView.imageView.clipsToBounds = true
        zoomingImageView.imageView.contentMode = UIViewContentMode.ScaleAspectFill
        return zoomingImageView.imageView
    }
    
    public func transitionDestinationImageView(sourceImageView: UIImageView) {
        
        guard let sourceImage = sourceImageView.image else {
            return
        }
        
        var height = CGFloat(0.0)
        var width = CGFloat(0.0)
        
        height = (CGRectGetWidth(self.view.frame) * sourceImage.size.height) / sourceImage.size.width
        width  = CGRectGetWidth(self.view.frame)
        
        sourceImageView.frame = CGRect(x: 0.0, y: 0.0, width: width, height: height)
        sourceImageView.center = CGPoint(
            x: CGRectGetWidth(self.view.frame) * 0.5,
            y: CGRectGetHeight(self.view.frame) * 0.5
        )
    }
    
    // MARK: - Private Method
    
    func imageResources() -> Array<AnyObject>? {
        
        if self.usingImageType == .URL {
            return self.imageURLs
        } else if self.usingImageType == .Image {
            return self.images
        } else if self.usingImageType == .Photo {
            return self.photos
        }
        
        return nil
    }
    
    func updateCaption() {
        
        if self.usingImageType == .Photo {
            if self.imageResources()?.count > 0 {
                let photo = self.photos![self.currentPage] as Photo
                UIView.animateWithDuration(0.1, delay: 0.0, options: UIViewAnimationOptions.CurveLinear, animations: { () -> Void in
                    self.captionLabel.alpha = 0.0
                    }, completion: { (completed) -> Void in
                        
                        self.captionLabel.text = photo.caption
                        UIView.animateWithDuration(0.1, delay: 0.0, options: UIViewAnimationOptions.CurveLinear, animations: { () -> Void in
                            self.captionLabel.alpha = 1.0
                            }, completion: nil)
                        
                        
                })
            }
        }
        
    }
    
    func didSingleTap(sender: UIGestureRecognizer) {
        if self.pageLabel?.alpha == 0.0 {
            
            UIView.animateWithDuration(0.05, delay: 0.0, options: UIViewAnimationOptions.CurveLinear, animations: { () -> Void in
                self.closeButton?.alpha = 1.0
                self.shareButton?.alpha = 1.0
                self.captionLabel.alpha = 1.0
                if self.visiblePageControl {
                    self.pageControl.alpha = 1.0
                }
                if self.visiblePageLabel {
                    self.pageLabel?.alpha = 1.0
                }
                if self.visibleCallButton {
                    self.callButton?.alpha = 1.0
                }
                if self.visibleEmailButton {
                    self.emailButton?.alpha = 1.0
                }
                }, completion: nil)
            
        } else {
            
            UIView.animateWithDuration(0.05, delay: 0.0, options: UIViewAnimationOptions.CurveLinear, animations: { () -> Void in
                self.closeButton?.alpha = 0.0
                self.shareButton?.alpha = 0.0
                self.captionLabel.alpha = 0.0
                if self.visiblePageControl {
                    self.pageControl.alpha = 0.0
                }
                if self.visiblePageLabel {
                    self.pageLabel?.alpha = 0.0
                }
                if self.visibleCallButton {
                    self.callButton?.alpha = 0.0
                }
                if self.visibleEmailButton {
                    self.emailButton?.alpha = 0.0
                }
                }, completion: nil)
        }
    }
    
    
    public func dismissPhotoSlider() {
        isPresented = false
        UIDevice.currentDevice().setValue(NSNumber(integer: UIInterfaceOrientation.Portrait.rawValue), forKey: "orientation")
        
        repeat {
            UIDevice.currentDevice().setValue(NSNumber(integer: UIInterfaceOrientation.Portrait.rawValue), forKey: "orientation")
        } while UIApplication.sharedApplication().statusBarOrientation.isLandscape
        self.delegate?.photoSliderControllerWillDismiss?(self)
        self.dissmissViewControllerAnimated(true)
    }
    
}
