---
layout: post
title: "Optimised Collection and Evaluation of Selenium UI Test Result Data for Multiple Environments in the epages Continuous Delivery Pipeline"
date: "2016-02-23 10:47:30"
icon: wrench
categories: tech-stories selenium testing elk cdp elasticsearch logstash continuous-delivery
authors: ["Benjamin Nothdurft"]
---

[comment]: <> (Teaser)

We implemented a Selenium test report database with Elasticsearch, Logstash, Docker, CircleCi and Jenkins to ease the test evaluation process in our continuous delivery pipeline. Today we want to share the general ideas of the completed implementation and the pragmatic benefits for our company. Furthermore, this article should serve as an outline of the consolidated technical expertise gained throughout the engineering process of this project.

## Introduction

Currently our [ePages Selenium Framework](https://developer.epages.com/blog/2015/07/23/the-epages-selenium-framework.html) has evolved to a reputable instrument for quality assurance of the next iteration of the epages platform. The development teams are highly deliberated in implementing corresponding automated integration tests for each feature to safeguard the functionality of every cartridge (software module). 

In our continuous delivery pipeline we run all these provided tests in various sets on every possible type of epages environment, which is freshly installed or patched to the latest release candidate. Before releasing the next version increment of epages the evaluation of all test results from each epages machine is very important.

## Motivation

In the past an engineer of the release and test automation team needed to log in to a dozen of different pipeline machines – which simulate the various use cases of epages in production – to collect hundreds of test results, transfer them into our developer wiki and check them for failures on a daily basis.

This tedious collection task was soon identified as a major pain point. Hence, we decided to fully automate the process and figure out an effective, reliable and centralised storage solution for all test reports. 

## Requirements

After careful consideration we determined that two non-functional requirements should be in the focus of the intended solution:

* Simplicity: The solution needs to be easy to implement, test, configure and maintain.
* Expandability: Later on, the solution needs to be able to additionally handle other kinds of logs from our pipeline machines.

## Two Solution Approaches

At first glance we had two different ideas for our architectural implementation:

* Option A: Custom python scripts at the end of a Selenium Jenkins job should transfer the test results from a pipeline machine into a dedicated single MySQL database. Another script or a custom frontend should then retrieve all test results from the database at the end of a whole pipeline run and display them in an usable fashion.
* Option B: Take the popular ELK-stack (Elasticsearch, Logstash, Kibana) as a basis, adapt it to fit our test results and throw each part in an independent docker container. Test the individual containers in CircleCi and - after success - push them to our docker registry. Let the pipeline pull the containers on-time and run them with the dedicated configuration for each Jenkins job.

After a team-internal discussion we concluded that we wanted to implement the option (B) as it relied on a recently established technology stack which got quite a lot of attention in terms of large-scale and high-performance system log monitoring.
Additionally considering the ease of extension in the future as well as a low effort for maintenance of the implemented solution we strongly opted against building every solution part on our own as suggested by the option (A).

## Implementation

### Part 1: Define Test Object and Extend Test Suite Reporter

Our inital task consisted of the definiton of the desired target format for the individual test objects, which would later be stored in elasticsearch as JSON documents. We determined to create a single object for each test case and represent it as a simple JSON object (without nested fields, like arrays) as this could be later on easier displayed by several client interfaces of the database.

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

Some information could be easily gathered by extending our TestReporter in the test suite core. The implemented ouput JSON log file contains test objects with the following fields: browser, pos, result, timestamp, test, class, method, runtime and the stacktrace. The other fields will need to be enriched at the proccessing step in the pipeline. We will discuss these entries in the logstash chapter.

We determined to create the JSON log in the reduced format and let logstash do the enrichment with the other fields at the time the test result objects will be processed in the pipeline and directly before forwarding them to elasticsearch.

### Part 2: Set up Elasticsearch using Docker and CircleCi

- circleci test
- docker
- official base image
- general configuration

### Part 3: Set up Logstash using Docker and CircleCi

- forwarder = processor and shipper
- describe transformation process
- templating
- input: esf-report.json, template-esf.json
- output: logstash-info.json, logstash-error.json

### Part 4: Integrate Docker Containers in Continuous Delivery Pipeline using Jenkins

- jenkins
- one job
- all jobs but without overwriting exit code
- when stable also us exit code

```bash
==== Start docker container ===

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

### Part 5: Set up Elasticsearch UI Client to Evaluate Test Results

- Viewer
- Rest-Client
- Head-Plugin

## Summary

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
- [x] Add picture: Solution draft
- [x] Add paragraph: Step 1: Extend test suite reporting
- [ ] Add snippet: Test data structure
- [ ] Add paragraph: Step 2: Set up elasticsearch
- [ ] Add paragraph: Step 3: Set up logstash
- [ ] Add snippet: Test data transformation
- [ ] Add paragraph: Step 4: Integrate solution in continuous delivery pipeline
- [ ] Add paragraph: Step 5: Usage
- [ ] Add picture: Test data in database and clients
- [ ] Add paragraph: Summary

## Comments

[comment]: <> (old: Log/Report evaluation of selenium ui test results in a continuous delivery pipeline using logstash and elasticsearch with the help of docker, circleci and jenkins.)
[comment]:  <> (old: fail for the next version of epages so that our plattform can be rolled out with zero-downtime and no errors to our providers in every operation scenario.)
[comment]:  <> (old: Automated GUI Testing has evolved to a reputable standard at ePages. A software engineer who is responsible for implementing a new feature or even develops a complete cartridge not even writes a lot of unit tests but also secures the functionality by adding appropriate integration tests with our ePages Selenium Framework.)
[comment]:  <> (old: - Pipeline with Continous delivery)
[comment]:  <> (old: - Test results from various environments)

## Notes

- 2 Lösungsansätze: eigeneDB e.g. MySQL mit Scripten (A) vs Elasticsearch, Logstash plus Kibana (B)
- A: needs database schema and maintenance of it, less flexibilty
- B: Perspektive Logsauswertung in pipeline, Learn use of ELK as some providers use it for sys logs on live systems

- After careful evaluation of XYZ
- Also opted against pre-db like redis
- choose most simplest approach to reduce complexity and gain stability
- Task breakdown structure