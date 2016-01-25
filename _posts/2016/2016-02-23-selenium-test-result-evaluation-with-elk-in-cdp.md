---
layout: post
title: "Optimised Collection and Evaluation of Selenium UI Test Result Data for Multiple Environments in the epages Continuous Delivery Pipeline"
date: "2016-02-23 10:47:30"
icon: wrench
categories: tech-stories selenium testing elk cdp elasticsearch logstash continuous-delivery
authors: ["Benjamin Nothdurft"]
---

#### Introduction and motivation:


#### Solution Approach:

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
