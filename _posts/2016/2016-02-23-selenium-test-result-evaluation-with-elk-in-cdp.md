---
layout: post
title: "Optimised Collection and Evaluation of Selenium UI Test Result Data for Multiple Environments in the epages Continuous Delivery Pipeline"
date: "2016-02-23 10:47:30"
icon: wrench
categories: tech-stories selenium testing elk cdp elasticsearch logstash continuous-delivery
authors: ["Benjamin Nothdurft"]
---

[comment]: <> (old: Log/Report evaluation of selenium ui test results in a continuous delivery pipeline using logstash and elasticsearch with the help of docker, circleci and jenkins.)

#### Teaser

We implemented an ELK-based selenium test report database to ease the test evaluation in our continuous delivery pipeline. Today we want to share with you the general ideas of the completed implementation and the pragmatic benefits for our team. This articel should also serve as an outline of the consolidated technical expertise gained throughout the engineering process of this project.

#### Introduction and Motivation

Currently our [ePages Selenium Framework](https://developer.epages.com/blog/2015/07/23/the-epages-selenium-framework.html) has evolved to a reputable instrument for quality assurance of the next version of the epages plattform. The development teams are highly deliberated in implementing a lot of new features with corresponding automated ui tests to safeguard the functionality of every cartridge. 

At the release automation team we run all the provided tests in various groups on every possible type of epages environment, which is installed or patched at each run of our continuous delivery pipeline. Before we can relase a new version of epages our daily business is to check that no test has failed on every epages environemnt. Every day there are several hundreds of test results that need to be evaluated on a dozen of different machines simulating all use cases in production.

Not too long ago our team has arrived at a point where it was a tedious hassle to collect the daily test logs and reports into our knowledge base so we decided to figure out an effictive, reliable and of course fully automated solution. Two essential/basic requirements needed to be met:

* Simplicity: The solution needs to be easy to implement, test, configure and maintain.
* Extendablility: The solution should also be able to handle other kinds of logs in our pipline and 

[comment]:  <> (old: fail for the next version of epages so that our plattform can be rolled out with zero-downtime and no errors to our providers in every operation scenario.)
[comment]:  <> (old: Automated GUI Testing has evolved to a reputable standard at ePages. A software engineer who is responsible for implementing a new feature or even develops a complete cartridge not even writes a lot of unit tests but also secures the functionality by adding appropriate integration tests with our ePages Selenium Framework.)
[comment]:  <> (old: - Pipeline with Continous delivery)
[comment]:  <> (old: - Test results from various environments)

#### Solution Approach

At first we had two basic ideas for our architectural basis:

* Option A:

- 2 Lösungsansätze: eigeneDB e.g. MySQL mit Scripten (A) vs Elasticsearch, Logstash plus Kibana (B)
- A: needs database schema and maintenance of it, less flexibilty
- B: Perspektive Logsauswertung in pipeline, Learn use of ELK as some providers use it for sys logs on live systems

#### Solution Draft:

- After careful evaluation of XYZ
- Also opted against pre-db like redis
- choose most simplest approach to reduce complexity and gain stability
- Task breakdown structure

#### 1 - Extend test suite reporting

- extend reporter

#### 2 - Set up elasticsearch

- circleci test
- docker
- official base image
- general configuration

#### 3 - Set up logstash

- forwarder = processor and shipper
- describe transformation process
- templating
- input: esf-report.json, template-esf.json
- output: logstash-info.json, logstash-error.json

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

#### 4 - Integrate solution in continuous delivery pipeline

- jenkins
- one job
- all jobs but without overwriting exit code
- when stable also us exit code

#### 5 - Usage

- Viewer
- Rest-Client
- Head-Plugin

#### Summary

- evaluation is much faster, do not have to connect to each job seperatly
- failures are also found much faster, but directly connecting to the cluster.
- Redundancy option by elasticsearch, nothing gets lost.
- A lot of learnings in the ELK area.
- Quiet satisfied with solution.

## Author

You may follow me at [@dataduke](https://twitter.com/dataduke).

## Writing Tasks

- [ ] Add paragraph: Introduction and motivation
- [ ] Add paragraph: Problem-Solving-Process
- [ ] Add paragraph: Solution approach
- [ ] Add picture: Solution draft
- [ ] Add paragraph: Step 1: Extend test suite reporting
- [ ] Add snippet: Test data structure
- [ ] Add paragraph: Step 2: Set up elasticsearch
- [ ] Add paragraph: Step 3: Set up logstash
- [ ] Add snippet: Test data transformation
- [ ] Add paragraph: Step 4: Integrate solution in continuous delivery pipeline
- [ ] Add paragraph: Step 5: Usage
- [ ] Add picture: Test data in database and clients
- [ ] Add paragraph: Summary

