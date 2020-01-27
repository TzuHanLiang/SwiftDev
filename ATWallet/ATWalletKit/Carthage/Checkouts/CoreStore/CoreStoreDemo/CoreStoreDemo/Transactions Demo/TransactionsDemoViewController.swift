//
//  TransactionsDemoViewController.swift
//  CoreStoreDemo
//
//  Created by John Rommel Estropia on 2015/05/24.
//  Copyright © 2018 John Rommel Estropia. All rights reserved.
//

import UIKit
import Contacts
import CoreLocation
import MapKit
import AddressBookUI
import CoreStore


private struct Static {

    static let dataStack = DataStack()

    static let placeController: ObjectMonitor<Place> = {
        
        try! Static.dataStack.addStorageAndWait(
            SQLiteStore(
                fileName: "PlaceDemo.sqlite",
                configuration: "TransactionsDemo",
                localStorageOptions: .recreateStoreOnModelMismatch
            )
        )
        
        var place = try! Static.dataStack.fetchOne(From<Place>())
        if place == nil {
            
            _ = try? Static.dataStack.perform(
                synchronous: { (transaction) in
                    
                    let place = transaction.create(Into<Place>())
                    place.setInitialValues()
                }
            )
            place = try! Static.dataStack.fetchOne(From<Place>())
        }
        
        return Static.dataStack.monitorObject(place!)
    }()
}


// MARK: - TransactionsDemoViewController

class TransactionsDemoViewController: UIViewController, MKMapViewDelegate, ObjectObserver {
    
    // MARK: NSObject
    
    deinit {
        
        Static.placeController.removeObserver(self)
    }
    
    
    // MARK: UIViewController
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        let longPressGesture = UILongPressGestureRecognizer(
            target: self,
            action: #selector(self.longPressGestureRecognized(_:))
        )
        self.mapView?.addGestureRecognizer(longPressGesture)
        
        Static.placeController.addObserver(self)
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(self.refreshButtonTapped(_:))
        )
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        
        let alert = UIAlertController(
            title: "Transactions Demo",
            message: "This demo shows how to use the 3 types of transactions to save updates: synchronous, asynchronous, and unsafe.\n\nTap and hold on the map to change the pin location.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
        
        if let mapView = self.mapView, let place = Static.placeController.object {
            
            mapView.addAnnotation(place)
            mapView.setCenter(place.coordinate, animated: false)
            mapView.selectAnnotation(place, animated: false)
        }
    }
    
    
    // MARK: MKMapViewDelegate
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        let identifier = "MKAnnotationView"
        var annotationView: MKPinAnnotationView! = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKPinAnnotationView
        if annotationView == nil {
            
            annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView.isEnabled = true
            annotationView.canShowCallout = true
            annotationView.animatesDrop = true
        }
        else {
            
            annotationView.annotation = annotation
        }
        
        return annotationView
    }
    
    
    // MARK: ObjectObserver
    
    func objectMonitor(_ monitor: ObjectMonitor<Place>, willUpdateObject object: Place) {
        
        // none
    }
    
    func objectMonitor(_ monitor: ObjectMonitor<Place>, didUpdateObject object: Place, changedPersistentKeys: Set<KeyPathString>) {
        
        if let mapView = self.mapView {
            
            mapView.removeAnnotations(mapView.annotations)
            mapView.addAnnotation(object)
            mapView.setCenter(object.coordinate, animated: true)
            mapView.selectAnnotation(object, animated: true)
            
            if changedPersistentKeys.contains(#keyPath(Place.latitude)) || changedPersistentKeys.contains(#keyPath(Place.longitude)) {
                
                self.geocode(place: object)
            }
        }
    }
    
    func objectMonitor(_ monitor: ObjectMonitor<Place>, didDeleteObject object: Place) {
        
        // none
    }

    
    // MARK: Private
    
    var geocoder: CLGeocoder?
    
    @IBOutlet weak var mapView: MKMapView?
    
    @IBAction dynamic func longPressGestureRecognized(_ sender: AnyObject?) {
        
        if let mapView = self.mapView,
            let gesture = sender as? UILongPressGestureRecognizer,
            gesture.state == .began {
            
            let coordinate = mapView.convert(
                gesture.location(in: mapView),
                toCoordinateFrom: mapView
            )
            Static.dataStack.perform(
                asynchronous: { (transaction) in
                    
                    let place = transaction.edit(Static.placeController.object)
                    place?.coordinate = coordinate
                },
                completion: { _ in }
            )
        }
    }
    
    @IBAction dynamic func refreshButtonTapped(_ sender: AnyObject?) {
        
        _ = try? Static.dataStack.perform(
            synchronous: { (transaction) in
                
                let place = transaction.edit(Static.placeController.object)
                place?.setInitialValues()
            }
        )
    }
    
    func geocode(place: Place) {
        
        let transaction = Static.dataStack.beginUnsafe()
        
        self.geocoder?.cancelGeocode()
        
        let geocoder = CLGeocoder()
        self.geocoder = geocoder
        geocoder.reverseGeocodeLocation(
            CLLocation(latitude: place.latitude, longitude: place.longitude),
            completionHandler: { [weak self] (placemarks, error) -> Void in
                
                if let placemark = placemarks?.first, let dictionary = placemark.addressDictionary {
                    
                    let place = transaction.edit(Static.placeController.object)
                    place?.title = placemark.name
                    place?.subtitle = CNPostalAddressFormatter.string(
                        from: autoreleasepool {
                            
                            let address = CNMutablePostalAddress()
                            (dictionary["Street"] as? String).flatMap({ address.street = $0 })
                            (dictionary["State"] as? String).flatMap({ address.state = $0 })
                            (dictionary["City"] as? String).flatMap({ address.city = $0 })
                            (dictionary["Country"] as? String).flatMap({ address.country = $0 })
                            (dictionary["ZIP"] as? String).flatMap({ address.postalCode = $0 })
                            return address
                        },
                        style: .mailingAddress
                    )
                    transaction.commit { (_) -> Void in }
                }
                
                self?.geocoder = nil
            }
        )
    }
}
