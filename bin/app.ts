#!/usr/bin/env node
import * as fs from 'fs';
import * as path from 'path';
import * as cdk from 'aws-cdk-lib';
import { CoreBootstrapStack } from '../lib/core-bootstrap-stack';

const app = new cdk.App();

// Load configuration from repositories.json
const configPath = path.join(__dirname, '..', 'repositories.json');
const configData = JSON.parse(fs.readFileSync(configPath, 'utf8'));

// Allow environment variable to override organization
const githubOwner = process.env.GITHUB_ORG || configData.githubOwner;

// Map repository config to include owner
const repositories = configData.repositories.map((repo: any) => ({
  owner: githubOwner,
  name: repo.name,
  environments: repo.environments,
}));

console.log(`Loading ${repositories.length} repositories for organization: ${githubOwner}`);

// Create the core bootstrap stack
new CoreBootstrapStack(app, 'CoreBootstrapStack', {
  owner: githubOwner,
  repositories,
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION,
  },
});

app.synth();
