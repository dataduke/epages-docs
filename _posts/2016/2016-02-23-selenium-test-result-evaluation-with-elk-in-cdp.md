---
layout: post
title: "Optimised Collection and Evaluation of Selenium UI Test Result Data for Multiple Environments in the epages Continuous Delivery Pipeline"
date: "2016-02-23 10:47:30"
icon: wrench
categories: tech-stories selenium testing elk cdp elasticsearch logstash continuous-delivery
authors: ["Benjamin Nothdurft", "Bastian Klein"]
---

[comment]: <> (Teaser)

We implemented a Selenium test report database with Elasticsearch, Logstash, Docker, CircleCi and Jenkins to ease the test evaluation process in our continuous delivery pipeline. Today we want to share the background information of the project, the general ideas of the implemented solution and discuss the pragmatic benefits for our company. 

Furthermore, this article should serve as an outline of the consolidated technical expertise gained throughout the engineering process of this project.

## Background Information

Currently our [ePages Selenium Framework](https://developer.epages.com/blog/2015/07/23/the-epages-selenium-framework.html) has evolved to a reputable instrument for quality assurance of the next iteration of the ePages platform. The development teams are highly deliberated in implementing corresponding automated integration tests for each feature to safeguard the functionality of every cartridge (software module). 

In our continuous delivery pipeline we run all these provided tests in various sets on every possible type of ePages environment, which is freshly installed or patched to the latest release candidate. Before releasing the next version increment of ePages the evaluation of all test results from each epages machine is very important.

### Motivation

In the past an engineer of the release and test automation team needed to log in to a dozen of different pipeline machines – which simulate the various use cases of ePages in production – to collect hundreds of test results, transfer them into our developer wiki and check them for failures on a daily basis.

This tedious collection task was soon identified as a major pain point. Hence, we decided to fully automate the process and figure out an effective, reliable and centralised storage solution for all test reports. 

### Requirements

After careful consideration we determined that two non-functional requirements should be in the focus of the intended solution:

* Simplicity: The solution needs to be easy to implement, test, configure and maintain.
* Expandability: Later on, the solution needs to be able to additionally handle other kinds of logs from our pipeline machines.

### Two Options

At first glance we had two different ideas for our architectural solution approaches:

* **Option A:** Custom python scripts at the end of a Selenium Jenkins job should transfer the test results from a pipeline machine into a dedicated single MySQL database. Another script or a custom frontend should then retrieve all test results from the database at the end of a whole pipeline run and display them in an usable fashion.
* **Option B:** Use the popular ELK-stack (Elasticsearch, Logstash, Kibana) as a basis, adapted it to fit our test results. Each part should be thrown in decoupled, independent docker containers. For scaleability we could create a distrusted storage cluster with data mirroring.Test-driven development of the individual containers could be achieved with CircleCi and - after success - the containers can be pushed to our docker registry. In the end the pipeline could pull the containers on-time and run them with a dedicated configuration for each Jenkins job.

After a team-internal discussion we concluded that we want to implement **Option B** as it relied on a recently established technology stack which got quite a lot of attention in terms of large-scale and high-performance system log monitoring.
Additionally considering the ease of extension in the future as well as a low effort for maintenance of the implemented solution we strongly opted against building every solution part on our own as suggested in **Option A**.

## Implemented Solution

2 describing sentences to the blueprint of the architecture.

![Blueprint of the Architecture](/path/to/img.jpg "Blueprint of the Architecture")

### Part 1: Define Test Object and Extend Test Suite Reporter

Our inital task consisted of the definiton of the desired target format for the individual test objects, which would later be stored in Elasticsearch as JSON documents. We determined to create a single object for each test case and represent it as a simple JSON object (without nested fields, like arrays) as this could be later on easier displayed by several client interfaces of Elasticsearch.

```JSON
{
    "epages_version": "6.17.39.1",
    "epages_repo_id": "6.17.39.1/2016.01.25-19.28.12",
    "env_os": "centos",
    "env_identifier": "distributed_three_hosts",
    "env_type": "install",
    "browser": "firefox",
    "timestamp": "2016-01-26T001726091Z",
    "pos": "3",
    "result": "FAILURE",
    "test": "DigitalTaxmatrixBasketTest.testDigitalTaxmatrixBasket",
    "class": "com.epages.cartridges.de_epages.tax.tests.DigitalTaxmatrixBasketTest",
    "method": "testDigitalTaxmatrixBasket",
    "runtime": "275",
    "report_url": "http://jenkins.intern.epages.de:8080/job/Run_ESF_tests/3778/artifact/esf/esf-epages6-1.15.0-SNAPSHOT/log/20160125T202150651Z/esf-test-reports/com/epages/cartridges/de_epages/tax/tests/DigitalTaxmatrixBasketTest/testDigitalTaxmatrixBasket/test-report.html",
    "stacktrace": "org.openqa.selenium.TimeoutException: Timed out after 30 seconds waiting for presence of element located by: By.className: Saved Build info: version: '2.47.1', System info: host: 'ci-vm-ui-test-004', ip: '127.0.1.1', os.name: 'Linux', os.arch: 'amd64', os.version: '3.13.0-43-generic', java.version: '1.8.0_45-internal' Driver info: org.openqa.selenium.support.events.EventFiringWebDriver at org.openqa.selenium.support.ui.WebDriverWait.timeoutException(WebDriverWait.java:80) at org.openqa.selenium.support.ui.FluentWait.until(FluentWait.java:229) at com.epages.esf.controller.ActionBot.waitFor(ActionBot.java:491) at com.epages.esf.controller.ActionBot.waitFor(ActionBot.java:468) at com.epages.esf.controller.ActionBot.waitFor(ActionBot.java:451) at com.epages.cartridges.de_epages.coupon.pageobjects.mbo.ViewCouponCodes.createmanualCouponCode(ViewCouponCodes.java:159) at com.epages.cartridges.de_epages.tax.tests.DigitalTaxmatrixBasketTest.setupCoupon(DigitalTaxmatrixBasketTest.java:882) at com.epages.cartridges.de_epages.tax.tests.DigitalTaxmatrixBasketTest.testDigitalTaxmatrixBasket(DigitalTaxmatrixBasketTest.java:172)"                                                                                               
}
```

Some information could be easily gathered by extending our TestReporter located in the core of our ePages selenium framework. Thus, we created a writer that could ouput log files containing single-line JSON test objects with the following fields: browser, pos, result, timestamp, test, class, method, runtime and the stacktrace. 

All other fields cannot be derived from our test suite itself and therefore need to be enriched at the processing step in the pipeline. We will discuss these ingredients of the test object in the following logstash chapter.

### Part 2: Set up Elasticsearch with Docker and CircleCi

**Dockerfile**

We decided to run [Elasticsearch](https://www.elastic.co/products/elasticsearch) from within an effortlessly deployable and stable docker container. To keep the entire setup at a reasonable level the reuse of the [offical base image](https://hub.docker.com/_/elasticsearch/) was very helpful. In the *Dockerfile* we synced our timezone, prepared templating with [Jinja](http://jinja.pocoo.org/docs/dev/) and installed several plugins for HTTP authorization and [administration](https://github.com/mobz/elasticsearch-head) via a web frontend that included a tabluar document view and a REST-console. We needed to create and use our own *docker-entrypoint* script as we wanted to map a few host directories to more docker volumes than suggested by the base image.

**Configuration**

Besides using variables in the configuration and logging files of Elasticsearch the setup was quite straight forward. We reduced complexity via a bash script allowing to build the docker image and start the container. The script support the setting of the needed variables for the configuration files and hands them over into the running docker container. 
For the operation of the Elasticsearch in our continuous delivery pipeline we implemented a verbose mode in the external bash script as well as the docker-entrypoint script so that we could follow each step in the console ouput.

**Testing**

We versioned the entire source code on [GitHub](https://github.com/). The first file we added was the configuration file for the CircleCi job. The job basically checks-out the repository and tries to build and run the docker container. After these preparation steps several tests check if the elasticsearch service is reachable form outside the container and working as expected. With this setup we could securely develop the Dockerfile and the Elasticsearch configuration files against the previously created tests. 
If a pull-reuest was reviewed and merged into the dev branch of the upstream repository an auto-merge-script pushed the dev code to the master branch. In the master branch – after 3 successful circleci job runs – the deployment of the docker image to our docker registry is triggered.


### Part 3: Set up Logstash with Docker and CircleCi

- forwarder = processor and shipper
- describe transformation process
- templating
- input: esf-report.json, template-esf.json
- output: logstash-info.json, logstash-error.json

### Part 4: Integrate Docker Containers in Continuous Delivery Pipeline using Jenkins

**Logstash**

We have several pipeline jobs that run the test suite of the ePages selenium framework on all ePages environment machines. As a result they produce a single log file with the JSON test objects as described in part 1. The test suite is configured to always append new objects so that it doesn't matter if the test suite is invoked in a matrix job, with several test groups in parallel or with a retry option for aborted test if thirdparty sandboxes fail. 

In such Jenkins jobs we added a separate build step where we first checked that all needed environment variables were used. 

If everything was setup as expected, we pulled the logstash container from the registry and used the start script to run the container accordingly. Below you can see a snippet of console output in verbose mode.

```bash
==== Start logstash docker container [to-logstash-esf_integration_run_on_non-windows_slaves-SEARCH-linux-1511] ===

Process logs with pattern:          *esf*.json
Mount log directory:                /home/jenkins/jenkins/workspace/esf_integration_run_on_non-windows_slaves/browser/firefox/groups_to_test/SEARCH/operating_system/linux/esf/esf-epages6-1.15.0-SNAPSHOT/log
Mount config directory:             /home/jenkins/jenkins/workspace/esf_integration_run_on_non-windows_slaves/browser/firefox/groups_to_test/SEARCH/operating_system/linux/to-logstash/config
Set logstash input types:           log,esf
Set logstash output types:          log,elasticsearch
Use logstash env file:              env-esf.list
Use logstash conf file:             logstash-esf.conf
Use info log file:                  logstash-info.json
Use error log file:                 logstash-error.json
Use elasticsearch template file:    template-esf.json
Set elasticsearch hosts:            [ 'cd-vm-docker-host-001.intern.epages.de:9200' ]
Set elasticsearch index:            esf-build-ui-tests
Set elasticsearch document type:    1511
```

All shipped test-objects are saved to a logstash info log, which is archived as build artifact in the clean-up section of Jenkins.

**Elasticsearch**

For our elasticsearch docker cluster we setup a new Jenkins job, which ensured that always the latest version of our container is running. We made sure to mount several host directories so that the elasticsearch data, config and logs are  stored on the VM and backuped with its snapshots.

### Part 5: Set up Elasticsearch UI Client to Evaluate Test Results

- Viewer
- Rest-Client
- Head-Plugin

## Summary and Discussion of Benefits

- evaluation is much faster, do not have to connect to each job seperatly
- failures are also found much faster, but directly connecting to the cluster.
- Redundancy option by elasticsearch, nothing gets lost.
- A lot of learnings in the ELK area.
- Quiet satisfied with solution.

## Author

You may follow me at [@dataduke](https://twitter.com/dataduke).

## Writing Tasks

- [x] Add paragraph: Introduction and motivation
- [x] Add paragraph: Problem-Solving-Process
- [x] Add paragraph: Solution approach
- [ ] Add paragraph: Implementation 
- [ ] Add picture: Solution draft
- [x] Add paragraph: Step 1: Extend test suite reporting
- [ ] Add snippet: Test data structure
- [ ] Add paragraph: Step 2: Set up elasticsearch
- [ ] Add paragraph: Step 3: Set up logstash
- [ ] Add snippet: Test data transformation
- [ ] Add paragraph: Step 4: Integrate solution in continuous delivery pipeline
- [ ] Add paragraph: Step 5: Usage
- [ ] Add picture: Test data in database and clients
- [ ] Add paragraph: Summary

## Notes

- old: Log/Report evaluation of selenium ui test results in a continuous delivery pipeline using logstash and elasticsearch with the help of docker, circleci and jenkins.
- old: fail for the next version of epages so that our plattform can be rolled out with zero-downtime and no errors to our providers in every operation scenario.
- old: Automated GUI Testing has evolved to a reputable standard at ePages. A software engineer who is responsible for implementing a new feature or even develops a complete cartridge not even writes a lot of unit tests but also secures the functionality by adding appropriate integration tests with our ePages Selenium Framework.
- old: Pipeline with Continous delivery
- old: Test results from various environments

- 2 Lösungsansätze: eigeneDB e.g. MySQL mit Scripten (A) vs Elasticsearch, Logstash plus Kibana (B)
- A: needs database schema and maintenance of it, less flexibilty
- B: Perspektive Logsauswertung in pipeline, Learn use of ELK as some providers use it for sys logs on live systems

- After careful evaluation of XYZ
- Also opted against pre-db like redis
- choose most simplest approach to reduce complexity and gain stability
- Task breakdown structure