# Introduction

This is a Starter application for using the Sample app in the AWS AppSync console when building your GraphQL API. The Sample app creates a GraphQL schema and provisions Amazon DynamoDB resources, then connects them appropriately with Resolvers. The application demonstrates GraphQL Mutations, Queries and Subscriptions using AWS AppSync. You can use this for learning purposes or adapt either the application or the GraphQL Schema to meet your needs.

![EventDetails](Media/EventDetails.png)

## Features

- GraphQL Mutations
  - Create new events
  - Create comments on existing events

- GraphQL Queries
  - Get all events (w/ pagination support)
  - Get an event by Id

- GraphQL Subscriptions
  - Real time updates for comments on an event

- Authorization
  - The app uses API Key as the authoriation mechanism

## AWS Setup

1. Navigate to the AWS AppSync console using the URL: http://console.aws.amazon.com/appsync/home

2. Click on `Create API` and select the `Sample Schema` option. Enter a API name of your choice. Click `Create`.

## iOS Setup

Clone this repository:

```
git clone https://github.com/aws-samples/aws-mobile-appsync-events-starter-ios.git
```

From the homepage of your GraphQL API (you can click the name you entered in the left hand navigation) wait until the progress bar at the top has completed deploying your resources. 

On this same page, select `iOS` at the bottom to download your `AppSync.json` configuration file. In the sample app which you just downloaded, copy the `API URL` and `API Key` from this JSON file and paste them into the `Constants.swift` file.

To setup the dependencies in the app, navigate to the project you just clined from a terminal and run: 

```
pod install
``` 

Now open `EventsApp.xcworkspace`.

## Application Walkthrough

### EventsAPI.swift

- The EventsAPI.swift file contains code generated through `aws-appsync-codegen` based on the GraphQL schema. It requires you to define a .graphql file and the schema.json for your API. For this example they are in events.graphql and schema-events.json. If you update your schema in the future, you will find updated versions of these in the AWS AppSync console under the homepage for your GraphQL API when you click the `iOS` tab. 

- To add new mutations, queries or subscriptions into your app, you could extend the events.graphql file to add additional operations.

- To generate a new API definition from the GraphQL schema, run:

 ```
 npm install aws-appsync-codegen

 aws-appsync-codegen generate events.graphql --schema schema-events.json --output EventsAPI.swift
 ```
 
This will generate an updated `EventssAPI.swift` file with additional operations.

### EventListViewController (Query)

- The `EventListViewController` file lists all the events accessible to the user. It returns data from the offline cache first if avialble and later fetches it from remote to update the local cache.

### EventDetailsViewController (Mutation, Query, Subscription)

- The `EventDetailsViewController` file list information about an event and allows new comments to be added. It also subscribes to live updates for new comments which are made on that post.

### AddEventViewController (Mutation)

- The `AddEventViewController` creates a new event using the details entered on screen. 
