<img src="https://s3.amazonaws.com/aws-mobile-hub-images/aws-amplify-logo.png" alt="AWS Amplify" width="225">

---

# Amplify UI Liveness Sample App

Amplify UI FaceLivenessDetector provides a UI component for Amazon Rekognition Face Liveness that helps developers verify that only real users, not bad actors using spoofs, can access your services.

More information on setting up and using the FaceLivenessDetector is in the [Amplify UI Face Liveness documentation](https://ui.docs.amplify.aws/swift/connected-components/liveness).

## Set Up

This sample app depends on AWS Amplify library and assumes Amplify Auth and Amplify API are configured.  You will need to either update the `amplifyconfiguration.json` with the missing configuration details or replace the placeholder file wit your `amplifyconfiguration.json` file.  For additional details on configuring Amplify, see [Face Liveness documentation](https://ui.docs.amplify.aws/swift/connected-components/liveness#step-1-configure-amplify)

To update the `amplifyconfiguration.json`:
Edit the file with the appropriate credential provider Pool ID and Region.
```
"Default": {
    "PoolId": "us-east-1:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "Region": "us-east-1"
}
```

This sample app assumes that the session id is fetched from an API REST endpoint, update the Amplify API Category section of the `amplifyconfiguration.json` file with the appropriate configuration for your REST API endpoint
```
"awsAPIPlugin": {
    "liveness": {
        "endpointType": "REST",
        "endpoint": "https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/xxxx",
        "region": "us-east-1",
        "authorizationType": "AWS_IAM"
    }
}
```

## Running Sample App
The sample app depends on a real device camera to capture videos.  Open the sample app in XCode and deploy the app onto a real device.

