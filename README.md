# CSA Scoring Walkthrough

This mini project provides an easy way to walk through the Cloud Suitability Analyzer's scoring process step by step.  There are a few components to this:

- This README provides the walkthrough and description of what's happening
- Two example applications used through the walkthrough, found in `portfolio`
- A set of custom rules

This walkthrough has some prerequisites to see the results described here:

1. You've installed the [latest CSA release](https://github.com/vmwarepivotallabs/csa-ui/releases/) locally and added it to your path
1. You've configured a higher file handle limit for your system (described in the CSA User Manual, but you can use `ulimit -n 20000` on MacOS to do this for your current terminal session)
1. You've removed all existing rules from your CSA database so that the only ones used are the custom rules in this walkthrough.  To do this, you need to connect to your `csa.db` SQLite instance and truncate the rules table with `delete from rules;`.

> Make sure to make a backup of your `csa.db` if you've already got custom rules or results in there that you'd like to save.  Alternatively, you can provide the `--database-dir` flag to CSA during this walkthrough to use a new database just for this.

## CSA Scoring, Step by Step

### Computing Effort for One App

CSA runs a bunch of rules against your application.  Depending on how rules are written, they might once in the whole application, once per file, or on individual lines of code.

Each rule contributes an effort score set inside the rule's definition, and the effort scores for all rules that match a project are summed together to form a _raw score_.

Because of the three different kinds of rules described above, the rules will fire at different frequencies for a project.  If they were all contributing the same effort score, rules that work on lines of code would quickly overwhelm the file- and application-level results.

As an example, imagine an app with 20 files each with 100 lines.  If we imagine a rule files that all contribute a score of 1 effort and that they fire for every app, file, and line of code, you'd end up with:

#### Small App
Type | Count | Effort | % Contribution to Score
--- | --- | --- | ---
App	| 1	| 1	| 0.000494805
Files | 20 | 20 | 0.009896091
Lines/File | 100 | 2000 | 0.989609104
Raw Score  | | 2021

Run this yourself with the following commands:
```bash
./load-unweighted-rules.sh
csa -p portfolio/small-app
csa ui
```
        
This shows that 99% of the total score is contributed by the line-based rules when all rules have the same effort associated.  We correct this by weighting the three types of rules differently when writing the rule itself.  We tend to use the following effort values for the three types of rules:

Rule Type | Score Range
--- | ---
Once per application: | 100-1000
Once per file: | 10 - 100
Multiple times per file: | 1 - 10

Updating our previous example, we see that lines still contribute a lot to the final score, but it's a little more balanced:
    
#### Small App
Type | Count | Weight | Effort | % Contribution to Score
--- | --- | --- | --- | ---
App | 1 | 100 | 100 | 0.043478261
Files | 20 | 10 | 200 | 0.086956522
Lines/File | 100 | 1 | 2000 | 0.869565217
Raw Score |  |  | 2300

Run this yourself with the following commands:
```bash
./load-weighted-rules.sh
csa -p portfolio/small-app
csa ui
```
    
> ***Question: Is there any guidance here to decide on a scores weight besides running the tool over and over to see what the overall impact is?  In this example, we still see that line-based rules are impacting a bunch. Is that good?***

### Comparing Effort Across Apps

Weighting the rules helps us balance the relationship between different kinds of rules run against a single app, but there's also the challenge of comparing total scores between two different apps.  If we have two apps of wildly different sizes but stick with the same rule efforts and assumptions as above:
    
#### Small App
Type | Count | Weight | Effort | % Contribution to Score
--- | --- | --- | --- | ---
App | 1 | 100 | 100 | 0.043478261
Files | 20 | 10 | 200 | 0.086956522
Lines/File | 100 | 1 | 2000 | 0.869565217
Raw Score |  |  | 2300

#### Large App
Type | Count | Weight | Effort | % Contribution to Score
--- | --- | --- | --- | ---
App | 1 | 100 | 100 | 6.62208E-05
Files | 1000 | 10 | 10000 | 0.006622078
Lines/File | 1500 | 1 | 1500000 | 0.993311701
Raw Score |  |  | 1510100

Run your rules against both apps and take a look at the raw scores on the Summary screen:
```bash
./load-weighted-rules.sh
csa -p portfolio
csa ui
```

> ***Question:  When we drastically increase the size of the project codebase, we all of a sudden see the app- and file-based rules being less impactful again.  Is this correct and intended?  Are these scaled with the size of the project?***

The total score as a sum of all the matching rule's efforts means that larger projects will by definition receive orders of magnitude larger effort scores.  We normalize this using a base 10 log of the total effort score:

- Small App:  log10(2300)  = **3.361727836**
- Large App:  log10(1510100) = **6.179005708**

The difference in effort is still present, but not at the scale that would make these impossible to compare.  A project with thousands of files _is_ probably more work to remediate than a project with only a handful of files.

Finally, CSA gives each project a score from 1-10 with 10 being the most cloud-ready, so we subtract the adjusted score from 10 to give us our final technical score:

- Small App:  10 - 3.361727836 = **6.638272164**
- Large App:  10 - 6.179005708 = **3.820994292**

You'll see these as the Technical Score in the Summary tab of the CSA UI for your most recent run:

```bash
csa ui
```

### Mapping Effort to Recommendations

Finally, we want to categorize these final technical scores into a set of recommendations.  These recommendations help bucket apps with specific technical and business scores in groups most suited to replatform, rehost, or rewrite.

This mapping of scores to recommendations is done through a model defined as an external YAML file (or the default version in memory).  The model is actually responsible for taking a project's raw score and, based on the project's manually-defined business value, running it through the normalizing function (`max_score - log10(raw_score)` as shown above in the Default model) and providing a recommendation description such as "rehost on TKG" or "run as a Knative function".  You'll see these recommendations on the Charts tab of the Summary page in the CSA UI.

Some considerations based on this default model:
- This means that the manually-defined business value isn't taken into account computing the technical score, but _is_ taking into account when making the recommendation.
- The normalization function is attached to the business value bin, so you could potentially provide a model that computes the final score differently for lower or higher business value objects.  The default model does not make this distinction and all technical scores are computed the same way.

You can provide a new scoring model by exporting the existing Default model, editing the resulting YAML file, and then replacing the Default model with your changes.

```bash
csa score-models export --models-dir=customer-models
vim custom-models/Default.yaml
csa score-models import --models-dir=custom-models
```

If you've changed the values in the Default model, you can just rerun the `csa -p ...` to analyze with those changes.  If you've loaded a new model with a different name, you can specify that model as a parameter when analyzing:

```bash
csa -p portfolio -s "my-custom-model"
csa ui
```

You'll see the new model name in the Summary page's table, and the Charts page should show your new recommendations.