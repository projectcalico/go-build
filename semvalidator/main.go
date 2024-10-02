// Copyright (c) 2024 Tigera, Inc. All rights reserved.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/sirupsen/logrus"
)

var (
	dir     string
	skipDir string
	file    string
	org     string
	orgURL  string
	token   string
	debug   bool
)

func init() {
	flag.StringVar(&dir, "dirs", "", "comma separated list of directories to search for Semaphore pipeline files")
	flag.StringVar(&skipDir, "skip-dirs", "", "comma separated list of directories to skip when searching for Semaphore pipeline files")
	flag.StringVar(&file, "files", "", "comma separated list of Semaphore pipeline files")
	flag.StringVar(&org, "org", "", "Semaphore organization")
	flag.StringVar(&orgURL, "org-url", "", "Semaphore organization URL")
	flag.StringVar(&token, "token", "", "Semaphore API token")
	flag.BoolVar(&debug, "debug", false, "enable debug logging")
}

func inSkipDirs(path string, skipDirs []string) bool {
	if len(skipDirs) == 0 {
		return false
	}
	for _, skipDir := range skipDirs {
		if strings.HasSuffix(path, skipDir) {
			return true
		}
	}
	return false
}

func getPipelineYAMLFiles(dir string, skipDirs []string) ([]string, error) {
	var files []string
	err := filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		// Skip the YAML .semaphore/semaphore.yml.d directory
		// as it contains building blocks which are not full pipeline definitions
		// The resulting pipeline will be validated as part of semaphore.yml and semaphore-scheduled-builds.yml
		if info.IsDir() && !inSkipDirs(path, skipDirs) {
			return filepath.SkipDir
		}
		if !info.IsDir() && (filepath.Ext(path) == ".yml" || filepath.Ext(path) == ".yaml") {
			files = append(files, path)
		}
		return nil
	})
	return files, err
}

func validateYAML(file, baseURL, token string) error {
	logrus.WithField("file", file).Info("validating YAML")
	content, err := os.ReadFile(file)
	if err != nil {
		logrus.WithError(err).Error("failed to read file")
		return err
	}
	payload := map[string]string{
		"yaml_definition": fmt.Sprintf("%v", string(content)),
	}
	data, err := json.Marshal(payload)
	if err != nil {
		logrus.WithError(err).Error("failed to marshal payload for yaml validation")
		return err
	}
	req, err := http.NewRequest(http.MethodPost, fmt.Sprintf("%s/api/v1alpha/yaml", baseURL), bytes.NewBuffer(data))
	if err != nil {
		logrus.WithError(err).Error("failed to create request for yaml validation")
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", token))
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		logrus.WithError(err).Error("failed to make request for yaml validation")
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("failed to validate YAML: %s", resp.Status)
	}
	result := map[string]interface{}{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		logrus.WithError(err).Error("failed to decode response for yaml validation")
		return err
	}
	logrus.Debug(result["message"].(string))
	return nil
}

func main() {
	flag.Parse()
	if debug {
		logrus.SetLevel(logrus.DebugLevel)
	}
	// Validate flags
	if orgURL == "" && org == "" {
		logrus.Fatal("Either Semaphore organization URL or organization name is required, use the -org-url or -org flag to specify the organization")
	} else if orgURL != "" && org != "" {
		logrus.Fatal("Only one of Semaphore organization URL or organization name is required, use either the -org-url or -org flag to specify the organization")
	}
	if token == "" {
		if os.Getenv("SEMAPHORE_API_TOKEN") == "" {
			logrus.Fatal("Semaphore API token is required, use the -token flag to specify the token or set as environment variable SEMAPHORE_API_TOKEN")
		} else {
			token = os.Getenv("SEMAPHORE_API_TOKEN")
		}
	}

	// Get YAML files
	var yamlFiles []string
	if file != "" {
		yamlFiles = strings.Split(file, ",")
	}
	if dir != "" {
		semaphoreDirs := strings.Split(dir, ",")
		logrus.WithField("semaphoreDirs", semaphoreDirs).Debug("looking for pipeline YAML files")
		for _, semaphoreDir := range semaphoreDirs {
			files, err := getPipelineYAMLFiles(semaphoreDir, strings.Split(skipDir, ","))
			if err != nil {
				logrus.WithError(err).Errorf("failed to get YAML files in %s", semaphoreDir)
				continue
			}
			yamlFiles = append(yamlFiles, files...)
		}
	}
	if len(yamlFiles) == 0 {
		logrus.Fatal("no YAML files found, use either -dirs or -files to specify the location of Semaphore pipeline files")
	}
	logrus.Debugf("will validate %d YAML pipeline file(s)", len(yamlFiles))
	var failedFiles []string

	// Send YAML files for validation
	baseURL := orgURL
	if org != "" {
		baseURL = fmt.Sprintf("https://%s.semaphoreci.com", org)
	}
	for _, file := range yamlFiles {
		err := validateYAML(file, baseURL, token)
		if err != nil {
			logrus.WithError(err).Error("invalid YAML definition")
			failedFiles = append(failedFiles, file)
		}
	}
	if len(failedFiles) > 0 {
		logrus.Fatalf("failed to validate %d files", len(failedFiles))
	} else {
		logrus.Info("all pipeline YAML files are valid")
	}
}
