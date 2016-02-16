//
//  ZoomingAnimationController.swift
//  Pods
//
//  Created by nakajijapan on 2015/09/13.
//
//

import UIKit

public protocol ZoomingAnimationControllerTransitioning {
    func transitionSourceImageView() -> UIImageView
    func transitionDestinationImageView(sourceImageView: UIImageView)
}

public class ZoomingAnimationContext: NSObject, UIViewControllerContextTransitioning {
    
    private var privateViewControllers:[String:UIViewController] = [:]
    private weak var privateContainerView:UIView?
    private var privatePresentationStyle:UIModalPresentationStyle = .Custom
    public var completionBlock: ((Bool) -> ())?
    private var animated:Bool = true
    private var interactive:Bool = false
    
    public init(fromViewController:UIViewController, toViewController:UIViewController) {
        self.privateContainerView = fromViewController.view.superview;
        self.privateViewControllers = [
            UITransitionContextFromViewControllerKey:fromViewController,
            UITransitionContextToViewControllerKey:toViewController,
        ]
    }
    
    public func targetTransform() -> CGAffineTransform {
        return CGAffineTransformIdentity
    }
    
    
    public func containerView() -> UIView? {
        return self.privateContainerView
    }
    
    public func presentationStyle() -> UIModalPresentationStyle {
        return self.privatePresentationStyle
    }
    
    public func isAnimated() -> Bool {
        return self.animated
    }
    
    public func isInteractive() -> Bool {
        return self.interactive
    }
    
    public func viewControllerForKey(key: String) -> UIViewController? {
        return self.privateViewControllers[key]
    }
    
    public func viewForKey(key: String) -> UIView? {
        return self.privateViewControllers[key]?.view
    }
    
    public func initialFrameForViewController(vc: UIViewController) -> CGRect {
        return self.privateContainerView?.bounds ?? CGRectZero
    }
    
    public func finalFrameForViewController(vc: UIViewController) -> CGRect {
        return self.privateContainerView?.bounds ?? CGRectZero
    }
    
    public func completeTransition(didComplete: Bool) {
        self.completionBlock?(didComplete)
    }
    
    public func transitionWasCancelled() -> Bool {
        return false
    }
    
    public func updateInteractiveTransition(percentComplete: CGFloat) {
        
    }
    
    public func finishInteractiveTransition() {
        
    }
    
    public func cancelInteractiveTransition() {
        
    }
}

public class ZoomingAnimationController: NSObject, UIViewControllerAnimatedTransitioning {
    
    var present = true
    public var sourceTransition: ZoomingAnimationControllerTransitioning?
    public var destinationTransition: ZoomingAnimationControllerTransitioning?
    
    public init(present: Bool) {
        super.init()
        self.present = present
    }
    
    public func transitionDuration(transitionContext: UIViewControllerContextTransitioning?) -> NSTimeInterval {
        return 0.2
    }
    
    public func animateTransition(transitionContext: UIViewControllerContextTransitioning) {
        
        if self.present {
            self.animatePresenting(transitionContext)
        } else {
            self.animateDismiss(transitionContext)
        }
    }
    
    func animatePresenting(transitionContext:UIViewControllerContextTransitioning) {
        
        let fromViewController = transitionContext.viewControllerForKey(UITransitionContextFromViewControllerKey)!
        let toViewController = transitionContext.viewControllerForKey(UITransitionContextToViewControllerKey)!
        let containerView = transitionContext.containerView()!
        
        let snapshotView = fromViewController.view.resizableSnapshotViewFromRect(fromViewController.view.frame, afterScreenUpdates: true, withCapInsets: UIEdgeInsetsZero)
        containerView.addSubview(snapshotView)
        
        toViewController.view.alpha = 0.0
        containerView.addSubview(toViewController.view)
        
        
        let backgroundView = UIView(frame: fromViewController.view.frame)
        backgroundView.backgroundColor = UIColor.blackColor()
        backgroundView.alpha = 0.0
        containerView.addSubview(backgroundView)
        
        let sourceImageView = self.sourceTransition!.transitionSourceImageView()
        containerView.addSubview(sourceImageView)
        
        
        UIView.animateWithDuration(
            self.transitionDuration(transitionContext),
            delay: 0.0,
            options: UIViewAnimationOptions.CurveEaseOut,
            animations: { () -> Void in
                
                self.destinationTransition!.transitionDestinationImageView(sourceImageView)
                backgroundView.alpha = 1.0
                
            }) { (result) -> Void in
                
                sourceImageView.alpha = 0.0
                sourceImageView.removeFromSuperview()
                
                toViewController.view.alpha = 1.0
                backgroundView.removeFromSuperview()
                
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled())
                
        }
        
    }
    
    func animateDismiss(transitionContext:UIViewControllerContextTransitioning) {
        
        let fromViewController = transitionContext.viewControllerForKey(UITransitionContextFromViewControllerKey)!
        let toViewController = transitionContext.viewControllerForKey(UITransitionContextToViewControllerKey)!
        let containerView = transitionContext.containerView()!
        
        
        
        var frame = containerView.bounds
        frame.origin.y += 20.0
        frame.size.height -= 20.0
        
        if let toViewController = toViewController as? UINavigationController {
            toViewController.view.frame = frame
        }
        
        containerView.addSubview(toViewController.view)
        containerView.addSubview(fromViewController.view)
        
        
        
        
        let sourceImageView = self.sourceTransition!.transitionSourceImageView()
        containerView.addSubview(sourceImageView)
        
        frame.origin.y -= 20.0
        frame.size.height += 20.0
        
        print("frame!!!: \(frame)")
        
        UIView.animateWithDuration(
            self.transitionDuration(transitionContext),
            delay: 0.0,
            options: UIViewAnimationOptions.CurveEaseOut,
            animations: { () -> Void in
                
                self.destinationTransition!.transitionDestinationImageView(sourceImageView)
                fromViewController.view.alpha = 0.1
                
            }) { (result) -> Void in
                
                sourceImageView.alpha = 0.0
                fromViewController.view.alpha = 0.0
                toViewController.view.frame = frame
                toViewController.view.layoutSubviews()
                sourceImageView.removeFromSuperview()
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled())
                
        }
    }
    
}
