# GitHub Actions 
Have you heard the saying “releases should be boring”? This is the unofficial motto of Continuous Integration and Continuous Deployment (CI/CD). GitHub Actions, announced at the 2018 GitHub Universe Conference, aims to bring boring releases to _all_ users in the GitHub Ecosystem. Today we’ll cover some of the core ideas that GitHub uses to accomplish this. Then we’ll build and deploy a serverless API using AWS, the Serverless Framework, and GitHub Actions.

## Social Coding
Social coding is a software development practice centered around the belief that community and collaboration build the best software. Open source software, public package managers like npm, version control software, and others are all examples of social coding. Social coding allows builders to share effort and to work collaboratively on software. GitHub Actions is an important step forward in social coding.

Automation and CI/CD tend to be boilerplate-heavy. This leads to repetitive code and time wasted on work that doesn’t actually differentiate your application. Actions enables streamlined access to automation tools _and_ the ability to easily share these tools. Actions is Docker-based which affords portability and ease-of-sharing. GitHub takes advantage of this by allowing builders to incorporate Actions from any public GitHub repository or any Docker image on DockerHub. Of course, if a particular Action does not exist a builder can create custom Actions and optionally share them in a public repository. The combination of integrated automation tools and ease-of-sharing is what makes Actions an excellent strategic opportunity for GitHub and a boon for builders in GitHub ecosystem.

In any large-scale social coding platform it’s important to be aware of potential issues caused by version changes and vulnerabilities introduced accidentally or maliciously. Actions is no exception. GitHub has addressed some of the issues including access control and version-pinning, but there are some other issues which we will explore later. Next, we’ll dive into the core concepts of GitHub Actions. 

## Core Concepts

### Actions
Actions are “code that run in Docker containers”.  Although Actions share their name with the wider service, they can be thought of as the individual units of work to be performed. Each Action has a unique name and one required attribute, namely  `uses`.  Actions are defined as follows:

```
action "Unique Name" {
  uses = "./helloworld"
}
```

The `uses` attribute can reference an Action in the same repo, a public Action in a GitHub repository, or a public Docker container hosted on Dockerhub. You can provide other optional attributes depending on your needs. A few common attributes including `needs` , `secrets`, and `args` will be discussed later. For a full list of attributes see the official documentation [official documentation](https://developer.github.com/actions/creating-workflows/workflow-configuration-options/#actions-attributes).

### Events 
Events are “happenings” within your GitHub repository including `pull_request_review`, `push`, and `issues`. Events trigger different workflows and generate a different environmental context depending on the type of event. This is important because the commit that the Action runs against depends on the event type triggering the Action. 

For example, the `release` event resolves the `GITHUB_SHA` (the commit hash) by the tag that triggered the release. So, an Action triggered by the `release` event uses the latest commit SHA of the branch.

But, the `push` event’s `GITHUB_SHA` is “Event specific unless deleting a branch (when it's the default branch)”. This means that it grabs the commit SHA directly from the triggering event. 

You can read more about the available events and the SHA resolutions in the [official documentation](https://developer.github.com/actions/creating-workflows/workflow-configuration-options/#events-supported-in-workflow-files). 

### Workflows
Workflows are composed of Actions and are triggered by Events. Put another way, Workflows combine Events and Actions. Workflows are defined using the `workflow` block. Each `workflow` block needs a unique name and has two required attributes: `on` and `resolves`. In the `on` attribute you define the Event type that triggers the Workflow. In the `resolves` attribute you describe the Actions to be “resolved” by the workflow. The `workflow` block definition reads like a sentence in English: “The workflow named Deploy Staging, on the release event, resolves build, test and deploy.” 

```
workflow "Deploy Staging" {
  on = "release"
  resolves = ["build", "test", "deploy"]
}
```

The `resolves` attribute deserves a little more attention, which we will cover next.

### Dependency
Dependency between Actions can be expressed using the `needs` attribute.  In the example below, “Deploy” is dependent on the successful completion of “Build”, “Test”, and “Lint”. You’ll notice that we only include the “Deploy” action in the `resolves` attribute of the Workflow block. 
```
workflow "Deploy to Staging" {
  on = "release"
  resolves = "Deploy"
}

action "Build" {
  uses = "docker://image1"
}

action "Test" {
  uses = "docker://image2"
}

action "Lint" {
  uses = "docker://image3"
}

action "Deploy" {
  needs = ["Build", "Test", "Lint"]
  uses = "docker://image4"
}
```

This is because the “Deploy” Action is dependent on the completion of the “Build”, “Test”, and “Lint” actions. We can express complex dependencies using this style.  

### Parallelism 
My initial assumption was that, in the workflow above, “Build”, “Test”, and “Lint” would run in parallel considering they’re independent Actions. In practice, this hasn’t been the case. I also tried the following workflow format, which I also expected would run in parallel:
```
workflow "Deploy to Staging" {
  on = "release"
  resolves = ["Build", "Test"]
}

action "Build" {
  uses = "docker://image1"
}

action "Test" {
  uses = "docker://image2"
}
```

Once again, this was not the case and the above did not run in parallel. According to the documentation “[w]hen more than one action is listed [in the `resolves` attribute] the actions are executed in parallel.” This may just be a limitation of the Public Beta and I imagine GitHub will allow this parallelism in the future. 

### Workspace
The Workspace is the directory that your Action will do its work in.  Remember that Actions are Docker-based, so we can say that Actions set the Docker container’s `WORKDIR` to `/github/workspace`. 
The workspace directory contains a copy of the repository set to the `GITHUB_SHA`  from the Event that triggered the workflow. An Action can modify this directory, access the contents, create binaries, etc. We’ll use the Workspace to store the compiled Go binary generated by our Action. 

### Secrets Management
Actions allow access to secrets through the `secrets` attribute. You have to explicitly list which secrets an Action has permission to access. In the following example the “Deploy Hello World” Action is given permission to access the `AWS_ACCESS_KEY_ID` and the `AWS_SECRET_ACCESS_KEY`. 

```
action "Deploy Hello World" {
    needs = ["Build Hello World", "Lint Hello World"]
    uses = "serverless/github-action@master"
    secrets =  ["AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"]
    args = "deploy"
}
```

Secrets are added


## Deploy a Serverless API Using GitHub Actions
Next, we’ll build a serverless API that is built, linted, and released on each `push` to the master branch in our repository. There are a few prerequisites that you’ll need to complete this tutorial: 

### Prerequisites 
- An AWS Account (set up Free Tier Access Here) [AWS Free Tier](https://aws.amazon.com/free/)
- An AWS IAM User with Programmatic Access (see [here](https://github.com/serverless/serverless/issues/1439) for a good starter IAM Policy and note that you should always follow the Principle of Least Privilege when setting up an IAM User) 
- GitHub Account enrolled in the [GitHub Actions Beta](https://github.com/features/actions)
- Clone or fork of the repo https://github.com/alexbielen/go_github_actions/actions

### Serverless API Code
We’ll look at the `serverless.yml` file first. Serverless uses a minimal configuration language to link events with the desired computation. Here we are creating an http api `GET /hello` and handling the API event with the Go binary in  `bin/hello` . 

```yaml
# serverless.yml

...

functions:
  hello:
    handler: bin/hello
    events:
      - http:
          path: hello
          method: get
```

Next, we’ll view the source code for the `bin/hello` binary. This code uses Serverless Framework’s default Go template with a slight modification to the `message` body: 

```go
// hello/main.go

...

type Response events.APIGatewayProxyResponse

func Handler(ctx context.Context) (Response, error) {
	var buf bytes.Buffer

	body, err := json.Marshal(map[string]interface{}{
		"message": "Hello From Two Bulls!",
	})
	if err != nil {
		return Response{StatusCode: 404}, err
	}
	json.HTMLEscape(&buf, body)

	resp := Response{
		StatusCode:      200,
		IsBase64Encoded: false,
		Body:            buf.String(),
		Headers: map[string]string{
			"Content-Type": "application/json",
		},
	}

	return resp, nil
}

...
```

This function returns an `APIGatewayProxyResponse` which defines the status code, headers, and response body.

The `Makefile`  defines the build steps that the Action will run. Two things worth noting: This is using Go 1.11 module system and we’re setting the `GOOS` environment variable to `linux` since we’ll be running this function in AWS Lambda.

```makefile
build:
	export GO111MODULE=on
	env GOOS=linux go build -ldflags="-s -w" -o bin/hello hello/main.go
```

### GitHub Actions Code

Next we’ll take a look at the GitHub Actions Workflow and Action definitions. Here we’ve defined a Workflow that is triggered on every `push` event and resolves the “Deploy Hello World” Action. The “Deploy Hello World Action” `uses` an external Action, maintained by the Serverless GitHub organization. To refer to this Action we use the organization name, the repo name, and the commit-ish that we’d like pin the version to. The “Deploy Hello World” Action also `needs` the “Build Hello World” and “Lint Hello World” Actions, but these are defined in ur orepository and thus can be referenced using the relative path syntax. These will complete _before_ the “Deploy Hello World Action”. 

```
workflow "New workflow" {
    on = "push"
    resolves = "Deploy Hello World"
}

action "Build Hello World" {
    uses = "./actions/build"
}

action "Lint Hello World" {
    uses = "./actions/lint"
}

action "Deploy Hello World" {
    needs = ["Build Hello World", "Lint Hello World"]
    uses = "serverless/github-action@master"
    secrets =  ["AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"]
    args = "deploy"
}
```

These are the `Dockerfiles` for the “Build Hello World” and “Lint Hello World” actions, respectively. The “Build Hello World” action runs `make` and the steps in the `Makefile` discussed above. The “Lint Hello World” runs `go vet` against the source. 
```dockerfile
# actions/build/Dockerfile

FROM golang:1.11.4-stretch

LABEL "com.github.actions.name"="Hello World!"
LABEL "com.github.actions.description"="Write arguments to the standard output."

CMD make
```

```dockerfile
FROM golang:1.11.4-stretch

LABEL "com.github.actions.name"="Hello World!"
LABEL "com.github.actions.description"="Write arguments to the standard output."

CMD cd hello && go vet
```



- Limitations 	
	- Run for 58 minutes (queueing AND execution time) 
	- Each workflow can run up to 100 actions
	- Two workflows concurrently per repository
	- Security (how do we trust third-party containers) do we get notifications etc?

- Summary, Caveats
	- Desired Features
	- What they got right 






