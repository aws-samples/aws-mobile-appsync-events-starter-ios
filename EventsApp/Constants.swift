//
//  Constants.swift
//  EventsApp
//

import Foundation
import AWSCore
import AWSAppSync

// EVENTS APP CONFIGURATION

// The API Key for authorization
let StaticAPIKey = "API_KEY_HERE"

// The Endpoint URL for AppSync
let AppSyncEndpointURL: URL = URL(string: "https://YOURAPI_ENDPOINT/graphql")!

let AppSyncRegion: AWSRegionType = .USWest2
let database_name = "events-app-db"


class APIKeyAuthProvider: AWSAPIKeyAuthProvider {
    func getAPIKey() -> String {
        // This function could dynamicall fetch the API Key if required and return it to AppSync client.
        return StaticAPIKey
    }
}

