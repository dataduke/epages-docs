---
layout: post
title: "Optimised Collection and Evaluation of Selenium UI Test Result Data for Multiple Environments in the epages Continuous Delivery Pipeline"
date: "2016-02-23 10:47:30"
icon: wrench
categories: tech-stories selenium testing elk cdp elasticsearch logstash continuous-delivery
authors: ["Benjamin Nothdurft", "Bastian Klein"]
---

[comment]: <> (Teaser)

We implemented a Selenium test report database with Elasticsearch, Logstash, Docker, CircleCi and Jenkins to ease the test evaluation process in our continuous delivery pipeline (CDP). Today we want to share  with you the background story of the project, showcase the various parts of the implemented solution and discuss the pragmatic benefits for our pipeline and our speed-up for massive regression test evaluation. 

Furthermore, this article should serve as an outline of the consolidated technical expertise gained throughout the engineering process of this project.

## Background Story

Currently our [ePages Selenium Framework](https://developer.epages.com/blog/2015/07/23/the-epages-selenium-framework.html) has evolved to a reputable instrument for quality assurance of the next iteration of the ePages platform. The development teams are highly deliberated in implementing corresponding automated integration tests for each feature to safeguard the functionality of every cartridge (software module). 

In our continuous delivery pipeline we run all these provided tests in various sets on every possible type of ePages environment, which is freshly installed or patched to the latest release candidate. The evaluation of all test results from each ePages CDP machine is a fundamentally important duty before releasing the next version increment of ePages.

### Motivation

In the past an engineer of the release and test automation team needed to log in to a dozen of different pipeline machines – which simulate the various use cases of ePages in production – to collect hundreds of test results, transfer them into our developer wiki and check them for failures on a daily basis.

This tedious collection task was soon identified as a major pain point. Hence, we decided to fully automate the process and figure out an effective, reliable and centralised storage solution for all test reports. 

### Requirements

After careful consideration we determined that two non-functional requirements should be in the focus of the intended solution:

* Simplicity: The solution needs to be easy to implement, test, configure and maintain.
* Expandability: Later on, the solution needs to be able to additionally handle other kinds of logs from our pipeline machines.

### Two Options

At first glance we had two different ideas for our architectural solution approach:

* **Option A:** Custom python scripts at the end of a Selenium Jenkins job should transfer the test results from a pipeline machine into a dedicated single MySQL database. Another script or a custom frontend should then retrieve all test results from the database at the end of a whole pipeline run and display them in an usable fashion.
* **Option B:** Use the popular ELK-stack (Elasticsearch, Logstash, Kibana) as a basis and adapted it to fit our test results. Each part should be thrown in decoupled, independent docker containers. For scaleability we should create a distributed storage cluster including mirroring for node data. Test-driven development of the individual containers should be achieved with CircleCi and - after success - the containers can be pushed to our docker registry. In the end the pipeline could pull the containers on-time and run them with a dedicated configuration for each Jenkins job.

After a team-internal discussion we concluded that we want to implement **Option B** as it relied on a recently established ecosystem which got quite a lot of attention in terms of large-scale and high-performance system log monitoring. Like other key-value stores Elasticsearch supports a very flexible document structure, which does not need any database schema, and on top all documents could also be retrieved via simple REST calls, which leaves room for developing a custom-tailored client especially for our use case scenario.

Furthermore considering the ease of extension in the near future as well as a generally low effort for maintenance we strongly opted against building every solution part on our own as suggested in **Option A**.

## Blueprint of the Solution Architecture

To get the big picture for splitting the Scrum epic into several stories with tasks and acceptance criterias we created a visualization, which could prescindly highlight the various parts that needed to be implemented. The first blueprint draft was sketched by hand and look similar to this:

![Blueprint of the solution architecture](/assets/images/blog-selenium-test-result-evaluation-blueprint-blue.png "Blueprint of the solution architecture")

As you can see above, several parts of our infrastructure will be involved.

### Part 1: Define Test Object and Extend Test Suite Reporter

Our inital task consisted of the definiton of the desired target format for the individual test objects, which would later be stored in Elasticsearch as [JSON](http://www.json.org/) documents. We determined to create a single object for each test case and represent it as a simple JSON object (without nested fields, like arrays) as this could be later on easier displayed by several client interfaces of Elasticsearch.

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

Within our architecture we use Logstash as a shipper and processor of our test results. It is needed to read, format and dispatch the information to our Elasticsearch instance. With the Logstash configuration file, it is possible to define the input and the output of Logstash, as well as how the data has to be filtered before transferring it to Elasticsearch. The input is given by a file path, which can also contain a regular expression. As described above, we use a JSON log file that is parsed by Logstash. The filter is able to add and remove fields from the JSON object. The output declares where the formatted message should be sent to. In our case this is configurable by environment variables, which will be explained below. 

In the Logstash configuration, there is the possibility to use `if`-statements and environment variables. In addition to this, we decided to write our own templating engine based on the Jinja2 framework, because of the complexity of our desired format. This allows us to have an environment specific configuration for each VM the Docker Container is running on. To use this feature we forward some variables into our Container. Our entry point script renders the configuration templates and starts Logstash.

```
if (![tags]) { 
    # add needed env variables to event
    mutate {
        add_field => {
            "report_url" => "{{ ENV_URL }}%{test_url}"
        }
    }
}

###################################
# Remove not needed source fields #
###################################

# only if no error tags were created
if (![tags]) {

    # remove not needed fields from extraction of message
    mutate { remove_field => [ "host", "message", "path", "test_url", "@timestamp", "@version" ] }
}

######################
# Create document id #
######################

# only if no error tags were created
if (![tags]) {

    if [env_identifier] != "zdt" {
        # generate document logstash id from several esf fields
        fingerprint {
            target => "[@metadata][ES_DOCUMENT_ID]"
            source => ["epages_repo_id", "env_os", "env_type", "env_identifier", "browser", "class", "method"]
            concatenate_sources => true
            key => "any-long-encryption-key"
            method => "SHA1"    # return the same hash if all values of source fields are equal
        }
    } else {
        # do not overwrite results for zdt environment identifier
        fingerprint {
            target => "[@metadata][ES_DOCUMENT_ID]"
            source => ["epages_repo_id", "env_os", "env_type", "env_identifier", "browser", "class", "method", "report_url"]
            concatenate_sources => true
            key => "any-long-encryption-key"
            method => "SHA1"    # return the same hash if all values of source fields are equal
        }
    }
}
```

Above you can see an excerpt of the filter part of the configuration file. The first statement adds a new field `report_url` to the JSON object. Therefore, we concatenate an environment variable with a field that was defined in the original JSON object to obtain a complete URL. The second statement creates a fingerprint that will be added to a metadata field. The fingerprint will be created from the fields specified by the source key.

```
{%- if "elasticsearch" in LS_OUTPUT or "document" in LS_OUTPUT or "template" in LS_OUTPUT %}

############################
# Output for elasticsearch #
############################

# only if no error tags were created
if (![tags]) {

    # push esf events to elasticsearch
    elasticsearch {

       # set connection
       hosts => {{ ES_HOSTS }}
       
       {%- if ES_USER and ES_PASSWORD %}
       
       # set credentials
       user => "{{ ES_USER }}"
       password => "{{ ES_PASSWORD }}"
       {%- endif %}
       
       {%- if "elasticsearch" in LS_OUTPUT or "document" in LS_OUTPUT %}
       
       # set document path
       index => "{{ ES_INDEX }}"
       document_type => "{{ ES_DOCUMENT_TYPE }}"
       document_id => "%{[@metadata][ES_DOCUMENT_ID]}"
       {%- endif %}
       
       {%- if "elasticsearch" in LS_OUTPUT or "template" in LS_OUTPUT %}
       
       # use template for settings and mappings
       manage_template => true
       template => "{{ LS_CONFIG_VOL }}/template-esf.json"
       template_name => "{{ ES_INDEX }}"
       template_overwrite => true
       {%- endif %}
    }
}
{%- endif %}
```
This excerpt shows how we organize the output to Elasticsearch. The first line represents how we use our own templating engine. If the `if`-statement is `false`, the part configuring the output to Elasticsearch will be omitted. If it equals `true`, we use environment variables as well as information from our metadata for connection, document path and template settings. The same construct we use to implement the output on stdout, to an info log file and to an error log file.

Another important point is testing our Logstash Container. We realized this with CircleCi. Every time a Pull Request is sent, CircleCi automatically tests these changes. We arranged two stages. On the first stage the Pull Request has to be reviewed and merged by a person into a dev branch. After this merge, CircleCi retests these changes. If the tests succeeds, the changes will be automatically merge into our master branch.

### Part 4: Integrate Docker Containers in Continuous Delivery Pipeline using Jenkins

**Logstash**

We have several pipeline jobs that run the test suite of the ePages selenium framework on all ePages environment machines. As a result they produce a single log file with the JSON test objects as described in part 1. The test suite is configured to always append new objects so that it doesn't matter if the test suite is invoked in a matrix job, with several test groups in parallel or with a retry option for aborted test if thirdparty sandboxes fail. 

In such Jenkins jobs we added a separate build step where we first checked that all needed environment variables were used. 

If everything was setup as expected, we pulled the logstash container from the registry and used the start script to run the container accordingly. Below you can see a snippet of console output in verbose mode.

```bash
=== Start docker container [to-logstash-run-esf-tests-3829] from image [epages/to-logstash:wip] ===

Process logs with pattern:          *esf*.json
Mount log directory:                /home/jenkins/workspace/Run_ESF_tests/esf/esf-epages6-1.15.0-SNAPSHOT/log
Mount config directory:             /home/jenkins/workspace/Run_ESF_tests/to-logstash/config
Set logstash input types:           log,esf
Set logstash output types:          log,elasticsearch
Use logstash env file:              env-esf.list
Use logstash conf file:             logstash-esf.conf
Use info log file:                  logstash-info.json
Use error log file:                 logstash-error.json
Use elasticsearch template file:    template-esf.json
Set elasticsearch hosts:            [ 'cd-vm-docker-host-001.intern.epages.de:9200' ]
Set elasticsearch index:            esf-cdp-ui-tests
Set elasticsearch document type:    6.17.40

--- Start configuration is applied.

a8fa29d74ef97832fcfbc3a0722b728a465244263c9d482b6eec6357d184555b

=== No need to stop not running docker container [to-logstash-run-esf-tests-3829] ===

=== Remove existing docker container [to-logstash-run-esf-tests-3829] ===

to-logstash-run-esf-tests-3829
```

All shipped test-objects are saved to a logstash info log, which is archived as build artifact in the clean-up section of Jenkins.

**Elasticsearch**

For our elasticsearch docker cluster we setup a new Jenkins job, which ensured that always the latest version of our container is running. We made sure to mount several host directories so that the elasticsearch data, config and logs are  stored on the VM and backuped with its snapshots.

### Part 5: Set up Elasticsearch UI Client to Evaluate Test Results

At the current state the ESClient is the analyzation tool of choice. Here you can browse and filter the documents via dropdown menus for the index, which is our test object type (e.g. cdp-ui-tests) and the document type, which is the epages repo id. You can then narrow down the search with simple match search field (e.g. only show results with resutlt FAILURE) or use the official [Lucence Query](http://www.lucenetutorial.com/lucene-query-syntax.html), which support boolean operators, range matchers and more advanced features, similar to a regex. It is possible to edit every single test object with client. Therefore the `note` can keep records on the cause for failures and corresponding JIRA case numbers, so that every unsuccessful test object is not just marked but also recorded.

![View Tests in Client](/assets/images/blog-selenium-test-result-evaluation-client-red.png "View Tests in Client")

Additionally, we also take advantage of three other usage scenarios:

* the [elasticsearch head](https://github.com/mobz/elasticsearch-head) plugin.
* the usage via browser and search URI requests. It is important to note that the query string should contain
	```bash
	Schema:
	<protocol>://<domain>:<port>/<index>/<document_type>/_count?=<query_string>
	<protocol>:/<domain>:<port>/<index>/<document_type>/_search?=<query_string>
	Query String:
	?pretty&size=1000&q=result:failure,skip AND epages_repo_id:*17.06.15
	```
* the usage via curl and [Elasticsearch DSL simple query string](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-simple-query-string-query.html)

## Summary and Discussion of Benefits

Today the evaluation process is much faster and we do not have to connect to each machine or Jenkins job individually. Our Elasticsearch cluster provides redundancy and backups. This saves a lot of time and we can focus on the test failures. We learned a lot during the project, especially in the area of how to apply TDD with services encapsulated Docker Containers and of course about the Elasticsearch and Logstash area, as we test huge amount of plugins and configurations.

Overall we are quiet satisfied with solution.

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

to part 3:

- forwarder = processor and shipper
- describe transformation process
- templating
- input: esf-report.json, template-esf.json
- output: logstash-info.json, logstash-error.json

