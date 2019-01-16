# GitHub Actions 
## Public Beta
## Social Coding 
GitHub Actions is an important step forward in social coding, a software development practice centered around the belief that community and collaboration build the best software. Automation and CI/CD are boilerplate-heavy and a relatively unexplored area of social coding. As such, Actions is an excellent strategic opportunity for GitHub and a boon for builders in GitHub ecosystem.

Actions are Docker-based which afford portability and ease-of-sharing. GitHub takes advantage of this by allowing builders to incorporate Actions from any public GitHub repository or any Docker image on DockerHub. Of course, if a particular Action does not exist a builder can create custom Actions and optionally share them in a public repository. 

In any large-scale social coding platform, it’s important to be aware of potential issues caused by versioning changes and vulnerabilities introduced accidentally or maliciously — Actions is no exception. GitHub has addressed some of the issues, including explicit control over access to secrets, and version-pinning, but there are some other issues which we will explore later. Next, we’ll explore some of the core ideas and abstractions that GitHub Actions uses. 

## Core Ideas

### Actions
Actions are “code that run in Docker containers”.  Although Actions share their name with the wider service, they can be thought of as the individual units of work to be performed. Each Action has a unique name, and one required attribute, namely  `uses`.  Actions are defined as follows:

```
action "Unique Name" {
  uses = "./helloworld"
}
```

The `uses` attribute can reference an Action in the repo using the relative path, a public Action on a GitHub repository, or a public Docker container hosted on Dockerhub.

There are other optional attributes including `needs` , `secrets`, and `args` which will be discussed later. For a full list of attributes see the official documentation [official documentation](https://developer.github.com/actions/creating-workflows/workflow-configuration-options/#actions-attributes).

### Events 
Events are happenings within your GitHub repository including `pull_request_review`, `push`, and `issues`. Events trigger different workflows, and generate a different environmental context depending on the type of event. This is important, because the commit that the Action checkouts out depends on which event triggered the Action. 

For example, the `release` event resolves the `GITHUB_SHA` by the tag that triggered the release. Because of this Actions uses the latest commit SHA of the branch in the triggering event. But, the `push` event’s `GITHUB_SHA` is “Event specific unless deleting a branch (when it's the default branch)”. This means that it grabs the commit SHA directly from the triggering event. 

You can read more about the available events and commits the commits that are checked out in the [official documentation](https://developer.github.com/actions/creating-workflows/workflow-configuration-options/#events-supported-in-workflow-files). 

### Workflows
Workflows combine Events and Actions into a single unit — that is, Workflows are composed of Actions and are triggered by Events. 
Workflows are defined using Workflow block. Each Workflow block needs a unique name, and has two required attributes: `on` and `resolves`. In the `on` attribute you define the Event type that triggers the Workflow. In the `resolves` attribute, which can be a string or list of strings, you describe the Actions that you would like to be “resolved” by the workflow. Ultimately, the workflow block definition reads like a sentence in English: “The workflow named Deploy Staging, on the release event, resolves build, test and deploy.” 

```
workflow "Deploy Staging" {
  on = "release"
  resolves = ["build", "test", "deploy"]
}
```

The `resolves` attribute deserves a little more attention, which we will cover next in Concurrency and Dependency.

### Dependency
Dependency between Actions can be expressed using the `needs` attribute.  In the example below, “Deploy” is dependent on the successful completion of “Build”, “Test”, and “Lint”. You’ll notice that we only include the “Deploy” action in the `resolves` attribute of the Workflow block. We can express complex dependencies using this style.  
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

According to the documentation “[w]hen more than one action is listed [in the `resolves` attribute] the actions are executed in parallel.” This may be a limitation of the Public Beta.

### Workspace
GitHub Actions sets the Docker container’s `WORKDIR` to `/github/workspace`. This is the directory that your Action will do most of its work in. The workspace directory contains a copy of the repository set to the `GITHUB_SHA`  from the Event that triggered the workflow. An Action can modify this directory, access the contents, create binaries, etc. 

### Secrets Management
Actions allow access to secrets through the `secrets` attribute. You have to explicitly define which secrets an Action can access. In the following example the Serverless Action is given permission to access 

```
action "Deploy Hello World" {
    needs = ["Build Hello World", "Lint Hello World"]
    uses = "serverless/github-action@master"
    secrets =  ["AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"]
    args = "deploy"
}
```

- Tutorial 
	- Pull code from twobulls Github
	- Prerequisites: Setup AWS Account (Free tier)
	- Setup IAM user (caveat about IAM user and policy needed)
	- Discuss Serverless Code
	- Discuss Makefile
	- Discuss Actions Code (Dockerfile)
	- Discuss Workflow Code 

- Limitations 	
	- Run for 58 minutes (queueing AND execution time) 
	- Each workflow can run up to 100 actions
	- Two workflows concurrently per repository
	- Security (how do we trust third-party containers) do we get notifications etc?

- Summary, Caveats
	- Desired Features
	- What they got right 






