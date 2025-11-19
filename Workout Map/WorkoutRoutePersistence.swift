//
//  WorkoutRoutePersistence.swift
//  Workout Map
//
//  Created by Codex on 11/18/25.
//

import CoreData
import Foundation
import MapKit

final class WorkoutRoutePersistence {
    static let shared = WorkoutRoutePersistence()

    private let container: NSPersistentContainer

    private init() {
        let model = WorkoutRoutePersistence.makeModel()
        container = NSPersistentContainer(name: "WorkoutRoutes", managedObjectModel: model)
        container.loadPersistentStores { _, error in
            if let error {
                assertionFailure("Failed to load persistence store: \(error)")
            }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func loadRoutes() -> [WorkoutRoute] {
        let context = container.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: Entity.name)
        request.sortDescriptors = [NSSortDescriptor(key: Route.startDate, ascending: false)]
        do {
            let managedObjects = try context.fetch(request)
            return managedObjects.compactMap { WorkoutRoute(from: $0) }
        } catch {
            return []
        }
    }

    func replaceAll(with routes: [WorkoutRoute]) {
        let context = container.newBackgroundContext()
        context.perform {
            do {
                try Self.clearAll(in: context)

                for route in routes {
                    Self.insert(route, into: context)
                }

                try context.save()
            } catch {
                // Ignore persistence errors for now; cache is best-effort.
            }
        }
    }

    func upsert(_ route: WorkoutRoute) {
        let context = container.newBackgroundContext()
        context.perform {
            Self.insert(route, into: context)
            do {
                try context.save()
            } catch {
                context.rollback()
            }
        }
    }

    func clearAll(synchronous: Bool = false, completion: (() -> Void)? = nil) {
        if synchronous {
            let context = container.viewContext
            context.performAndWait {
                _ = try? Self.clearAll(in: context)
                try? context.save()
            }
            completion?()
            return
        }

        let context = container.newBackgroundContext()
        context.perform {
            _ = try? Self.clearAll(in: context)
            try? context.save()
            if let completion {
                DispatchQueue.main.async(execute: completion)
            }
        }
    }
}

private extension WorkoutRoutePersistence {
    enum Entity {
        static let name = "WorkoutRouteEntity"
    }

    enum Route {
        static let id = "id"
        static let workoutIdentifier = "workoutIdentifier"
        static let name = "name"
        static let distance = "distance"
        static let startDate = "startDate"
        static let color = "color"
        static let coordinates = "coordinates"
    }

    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let entity = NSEntityDescription()
        entity.name = Entity.name
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let idAttribute = NSAttributeDescription()
        idAttribute.name = Route.id
        idAttribute.attributeType = .UUIDAttributeType
        idAttribute.isOptional = false

        let workoutAttribute = NSAttributeDescription()
        workoutAttribute.name = Route.workoutIdentifier
        workoutAttribute.attributeType = .UUIDAttributeType
        workoutAttribute.isOptional = true

        let nameAttribute = NSAttributeDescription()
        nameAttribute.name = Route.name
        nameAttribute.attributeType = .stringAttributeType
        nameAttribute.isOptional = false

        let distanceAttribute = NSAttributeDescription()
        distanceAttribute.name = Route.distance
        distanceAttribute.attributeType = .doubleAttributeType
        distanceAttribute.isOptional = false

        let startDateAttribute = NSAttributeDescription()
        startDateAttribute.name = Route.startDate
        startDateAttribute.attributeType = .dateAttributeType
        startDateAttribute.isOptional = false

        let colorAttribute = NSAttributeDescription()
        colorAttribute.name = Route.color
        colorAttribute.attributeType = .stringAttributeType
        colorAttribute.isOptional = false

        let coordinatesAttribute = NSAttributeDescription()
        coordinatesAttribute.name = Route.coordinates
        coordinatesAttribute.attributeType = .binaryDataAttributeType
        coordinatesAttribute.allowsExternalBinaryDataStorage = true
        coordinatesAttribute.isOptional = false

        entity.properties = [idAttribute, workoutAttribute, nameAttribute, distanceAttribute, startDateAttribute, colorAttribute, coordinatesAttribute]

        model.entities = [entity]
        return model
    }

    @discardableResult
    static func clearAll(in context: NSManagedObjectContext) throws -> Bool {
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: Entity.name)
        let delete = NSBatchDeleteRequest(fetchRequest: fetch)
        try context.execute(delete)
        return true
    }

    static func insert(_ route: WorkoutRoute, into context: NSManagedObjectContext) {
        let managedObject = NSEntityDescription.insertNewObject(forEntityName: Entity.name, into: context)
        managedObject.setValue(route.id, forKey: Route.id)
        managedObject.setValue(route.workoutIdentifier, forKey: Route.workoutIdentifier)
        managedObject.setValue(route.name, forKey: Route.name)
        managedObject.setValue(route.distanceInKilometers, forKey: Route.distance)
        managedObject.setValue(route.startDate, forKey: Route.startDate)
        managedObject.setValue(route.routeColor.rawValue, forKey: Route.color)
        managedObject.setValue(WorkoutRoutePersistence.encodeCoordinates(route.coordinates), forKey: Route.coordinates)
    }

    static func encodeCoordinates(_ coords: [CLLocationCoordinate2D]) -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let dto = coords.map { CoordinateDTO(latitude: $0.latitude, longitude: $0.longitude) }
        return (try? encoder.encode(dto)) ?? Data()
    }

    static func decodeCoordinates(from data: Data) -> [CLLocationCoordinate2D] {
        let decoder = JSONDecoder()
        if let dto = try? decoder.decode([CoordinateDTO].self, from: data) {
            return dto.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        }
        return []
    }

    struct CoordinateDTO: Codable {
        let latitude: Double
        let longitude: Double
    }
}

private extension WorkoutRoute {
    init?(from managedObject: NSManagedObject) {
        guard let id = managedObject.value(forKey: WorkoutRoutePersistence.Route.id) as? UUID,
              let name = managedObject.value(forKey: WorkoutRoutePersistence.Route.name) as? String,
              let distance = managedObject.value(forKey: WorkoutRoutePersistence.Route.distance) as? Double,
              let startDate = managedObject.value(forKey: WorkoutRoutePersistence.Route.startDate) as? Date,
              let colorRaw = managedObject.value(forKey: WorkoutRoutePersistence.Route.color) as? String,
              let color = WorkoutRoute.RouteColor(rawValue: colorRaw),
              let coordinatesData = managedObject.value(forKey: WorkoutRoutePersistence.Route.coordinates) as? Data else {
            return nil
        }

        let coordinates = WorkoutRoutePersistence.decodeCoordinates(from: coordinatesData)
        let workoutIdentifier = managedObject.value(forKey: WorkoutRoutePersistence.Route.workoutIdentifier) as? UUID

        self = WorkoutRoute(
            id: id,
            workoutIdentifier: workoutIdentifier,
            name: name,
            distanceInKilometers: distance,
            startDate: startDate,
            coordinates: coordinates,
            color: color
        )
    }
}
