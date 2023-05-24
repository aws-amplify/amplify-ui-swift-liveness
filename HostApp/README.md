<img src="https://s3.amazonaws.com/aws-mobile-hub-images/aws-amplify-logo.png" alt="AWS Amplify" width="225">

---

# Amplify UI Liveness Sample App

Amplify UI FaceLivenessDetector provides a UI component for Amazon Rekognition Face Liveness that helps developers verify that only real users, not bad actors using spoofs, can access your services.

More information on setting up and using the FaceLivenessDetector is in the [Amplify UI Face Liveness documentation](https://ui.docs.amplify.aws/swift/connected-components/liveness).

## Running the App

1. Install Xcode version 12.0 or higher
2. clone the Amplify UI Swift Liveness repository:
```
git clone https://github.com/aws-amplify/amplify-ui-swift-liveness.git
```
3. Change directory to `HostApp`
```
cd amplify-ui-swift-livenes/HostApp
```
4. Open HostApp.xcodeproj in Xcode

5. The sample app depends on a real device camera to capture videos.  Build and deploy the app onto a real device.

6. When the app is launch, click the Sign in button to sign up and then sign in.  

7. Once signed in and authenticated, the "Create Liveness Session" is enabled.  Click the button to generate and get a session id from your backend.

8. Once a session id is created, the Liveness Check screen is displayed.  Follow the instructions and click on Begin Check button to begin liveness verification.

## Provision AWS Backend Resources

1. Follow the [instructions](https://docs.amplify.aws/start/getting-started/installation/q/integration/ios/) to sign up for an AWS account and set up the Amplify CLI.
2. Initialize Amplify in the project by running the following command from the project directory:
```
amplify init
```
Provide the responses shown after each of the following prompts.
```
? Enter a name for the project: `LivenessHostApp`
The following configuration will be applied:

Project information
| Name: LivenessHostApp
| Environment: dev
| Default editor: Visual Studio Code
| App type: ios

? Initialize the project with the above configuration? No
? Enter a name for the environment: `dev`
? Choose your default editor: `Xcode (macOS only)`
? Choose the type of app that you're building: `ios`
? Select the authentication method you want to use:
`AWS profile`
? Please choose the profile you want to use
`default`
```
Wait until provisioning is finished. Upon successfully running `amplify init`, you will see a configuration file created called `amplifyconfiguration.json`. This file will be bundled into your application so that the Amplify libraries know how to reach your provisioned backend resources at runtime.  You can verify by checking that the file is included in the `Copy Bundle Resources` Build Phases for the `HostApp` target in Xcode.

3. Configure Auth Category

The Amplify Auth category provides an interface for authenticating a user and also provides the necessary authorization to other Amplify categories. It comes with default, built-in support for Amazon Cognito User Pools and Identity Pools. From your project directory, run the following command to add the Amplify Auth category:
```
amplify add auth
```
Provide the responses shown after each of the following prompts.
```
? Do you want to use the default authentication and security configuration? 
    `Default configuration with Social Provider (Federation)`
? How do you want users to be able to sign in? 
    `Username`
? Do you want to configure advanced settings? 
    `No, I am done.`
? What domain name prefix you want us to create for you? 
    `(default)`
? Enter your redirect signin URI: 
    `myapp://`
? Do you want to add another redirect signin URI 
    `No`
? Enter your redirect signout URI: 
    `myapp://`
? Do you want to add another redirect signout URI 
    `No`
? Select the social providers you want to configure for your user pool: 
    `<hit enter>`
```
4. Once finished, run `amplify push` to publish your changes.
   Upon completion, `amplifyconfiguration.json` should be updated to reference these provisioned backend resources.
5. Follow the steps below to create an inline policy to enable authenticated app users to access Rekognition, which powers the FaceLivenessDetector.
   1. Go to AWS IAM console, then Roles
   2. Select the newly created `authRole` for the project (`amplify-<project_name>-<env_name>-<id>-authRole`).
   3. Choose **Add Permissions**, then select **Create Inline Policy**, then choose **JSON** and paste the following:

    ```
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": "rekognition:StartFaceLivenessSession",
                "Resource": "*"
            }
        ]
    }
    ```

   4. Choose **Review Policy**
   5. Name the policy
   6. Choose **Create Policy**

6. Set up a backend to create the liveness session and retrieve the liveness session results. The liveness sample app is set up to use API Gateway endpoints for creating and retrieving the liveness session. Follow the [Amazon Rekognition Liveness guide](https://docs.aws.amazon.com/rekognition/latest/dg/face-liveness-programming-api.html) to set up your backend.

    1. Edit the [StartSessionViewModel.swift](https://github.com/aws-amplify/amplify-ui-swift-liveness/blob/main/HostApp/HostApp/Views/StartSessionViewModel.swift) in your project as necessary to generate the session id from your backend.
    2. Edit the [ExampleLivenessViewModel.swift](https://github.com/aws-amplify/amplify-ui-swift-liveness/blob/main/HostApp/HostApp/Views/ExampleLivenessViewModel.swift) in your project as necessary to get the liveness result from your backend.

## Sample Liveness Backend
The sample app utilizes a backend consisting of API Gateway and 2 Lambdas to interface with AWS Rekognition to create a session id and get the session result.  The following are steps to use Amplify CLI to configure a sample backend.

1. Run Amplify CLI to configure the API category with two REST API and two lambdas
    1. `livenessSessionHandler` lambda to create a session and return a session id
    2. `livenessResultHandler` lambda to return a liveness result given a liveness session id

```
amplify add api
```
```
➜ ✗ amplify add api
? Select from one of the below mentioned services: REST
✔ Provide a friendly name for your resource to be used as a label for this category in the project: · liveness
✔ Provide a path (e.g., /book/{isbn}): · /liveness/create
Only one option for [Choose a Lambda source]. Selecting [Create a new Lambda function].
? Provide an AWS Lambda function name: livenessSessionHandler
? Choose the runtime that you want to use: NodeJS
? Choose the function template that you want to use: Hello World
? Do you want to configure advanced settings? No
? Do you want to edit the local lambda function now? No
Successfully added resource livenessSessionHandler locally.
✅ Succesfully added the Lambda function locally
✔ Restrict API access? (Y/n) · no


✔ Do you want to add another path? (y/N) · yes
✔ Provide a path (e.g., /book/{isbn}): · /liveness/{sessionId}
Only one option for [Choose a Lambda source]. Selecting [Create a new Lambda function].
? Provide an AWS Lambda function name: livenessResultHandler
? Choose the runtime that you want to use: NodeJS
? Choose the function template that you want to use: Hello World
? Do you want to configure advanced settings? No
? Do you want to edit the local lambda function now? No
Successfully added resource livenessResultHandler locally.
✅ Succesfully added the Lambda function locally
✔ Restrict API access? (Y/n) · no
✔ Do you want to add another path? (y/N) · no
```

2. Modify the lambda to call AWS Rekognition to generate a session id.
    1. Navigate to <project-dir>/amplify/backend/function/livenessSessionHandler/src
    2. Update `index.js` with the following content
    
    ```js
    const { RekognitionClient, CreateFaceLivenessSessionCommand } = require("@aws-sdk/client-rekognition");

    /**
    * @type {import('@types/aws-lambda').APIGatewayProxyHandler}
    */
    exports.handler = async (event) => {
        const client = new RekognitionClient({ region: 'us-east-1' });
        const command = new CreateFaceLivenessSessionCommand({});
        const response = await client.send(command);
        console.log({ response });
        return {
        statusCode: 200,
        headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': '*',
        },
        body: JSON.stringify({ sessionId: response.SessionId }),
        };
    };
    ```

3. Modify the lambda to call AWS Rekognnition to get the session result
    1. Navigate to <project-dir>/amplify/backend/function/livenessResultHandler/src
    2. Update `index.js` with the following content
    
    ```js
    const { RekognitionClient, GetFaceLivenessSessionResultsCommand } = require("@aws-sdk/client-rekognition");

    /**
    * @type {import('@types/aws-lambda').APIGatewayProxyHandler}
    */
    exports.handler = async (event) => {
        console.log({ event });
        const client = new RekognitionClient({ region: 'us-east-1' });
        const command = new GetFaceLivenessSessionResultsCommand({
        SessionId: event.pathParameters.sessionId,
        });
        const response = await client.send(command);
        const isLive = response.Confidence > 90;
        
        console.log({ response });
        return {
        statusCode: 200,
        headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': '*',
        },
        body: JSON.stringify({
            isLive,
            confidenceScore: response.Confidence,
            auditImageBytes: Buffer.from(response.ReferenceImage.Bytes).toString('base64'),
        }),
        };
    };
    ```
4. Push the API configuration to the backend
```
amplify push
```

5. Provision the session lambda execution role with the create permission
    1. In AWS Console, navigate to `AWS Amplify` Service
    2. Click to navigate to your Amplify App
    3. In the `Backend environments` tab, click on the `Functions` link to view all your lambda functions.  There should be two that you created and pushed via the Amplify CLI
    4. Click on the session lambda
    5. Click on the `View in Lambda` button to redirect to the AWS Lambda service
    6. Click on the `Configuration` tab
    7. On the left menu, click on the `Permissions` menu item
    8. Under the `Execution role` section, click on the the role name that the lambda assumes during execution
    9. Choose **Add Permissions**, then select **Create Inline Policy**, then choose **JSON** and paste the following:

    ```
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": "rekognition:CreateFaceLivenessSession",
                "Resource": "*"
            }
        ]
    }
    ```

   4. Choose **Review Policy**
   5. Name the policy
   6. Choose **Create Policy**
6. Provision the result lambda execution role with the get result permission
    1. In AWS Console, navigate to `AWS Amplify` Service
    2. Click to navigate to your Amplify App
    3. In the `Backend environments` tab, click on the `Functions` link to view all your lambda functions.  There should be two that you created and pushed via the Amplify CLI
    4. Click on the result lambda
    5. Click on the `View in Lambda` button to redirect to the AWS Lambda service
    6. Click on the `Configuration` tab
    7. On the left menu, click on the `Permissions` menu item
    8. Under the `Execution role` section, click on the the role name that the lambda assumes during execution
    9. Choose **Add Permissions**, then select **Create Inline Policy**, then choose **JSON** and paste the following:

    ```
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": "rekognition:GetFaceLivenessSessionResults",
                "Resource": "*"
            }
        ]
    }
    ```

   4. Choose **Review Policy**
   5. Name the policy
   6. Choose **Create Policy**
7. Your backend environment should now be setup with two REST api to get a Liveness session and a Liveness session result

### Troubleshooting tips
1. Ensure permissions are set appropriately
    1. Depending on your use case, `rekognition:StartFaceLivenessSession` should be allowed for your authenticated or guest user configured in IAM
        * `amplify-<project_name>-<env_name>-<id>-authRole` for authenticated user or if you are using Authenticator UI component.
        * `amplify-<project_name>-<env_name>-<id>-unauthRole` for unauthenticated user
    2. `rekognition:CreateFaceLivenessSession` should be allowed for the create session handler lambda role in IAM
    3. `rekognition:GetFaceLivenessSessionResults` should be allowed for the get result handler lambda role in IAM
    4. Verify in AWS CloudWatch logs there are no `AccessDeniedException`

2. Ensure that your lambdas are deployed and starting.  Lambda logs are viewable in AWS CloudWatch
    1. In AWS Console, navigate to `AWS Amplify` Service
    2. Click to navigate to your Amplify App
    3. In the `Backend environments` tab, click on the `Functions` link to view all your lambda functions.  There should be two that you created and pushed via the Amplify CLI
    4. Click on the result lambda, check to see if there are any error logs here
    5. Click on the `View in CloudWatch` button to redirect to the AWS CloudWatch service
    6. Click on the latest Log stream to view the latest log events
    


