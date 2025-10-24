<a href="/resources/img/light_openMINDS-MATLAB-logo.png">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="/resources/img/dark_openMINDS-MATLAB-logo.png">
    <source media="(prefers-color-scheme: light)" srcset="/resources/img/light_openMINDS-MATLAB-logo.png">
    <img alt="openMINDS-MATLAB-logo" src="/resources/img/light_openMINDS-MATLAB-logo.png" title="openMINDS-MATLAB-GUI" align="right" height="70" width="141px"​>
  </picture>
</a>

# openMINDS-MATLAB-GUI

<h4 align="center">
  <a href="https://github.com/ehennestad/openMINDS-MATLAB-GUI/releases/latest">
    <img src="https://img.shields.io/github/v/release/ehennestad/openMINDS-MATLAB-GUI?label=version" alt="Version">
  </a>
  <a href="https://matlab.mathworks.com/open/github/v1?repo=ehennestad/openMINDS-MATLAB-GUI&file=code/gettingStarted.mlx">
    <img src="https://www.mathworks.com/images/responsive/global/open-in-matlab-online.svg" alt="MATLAB Online">
  </a>
  <a href="https://codecov.io/gh/ehennestad/openMINDS-MATLAB-GUI" > 
    <img src="https://codecov.io/gh/ehennestad/openMINDS-MATLAB-GUI/branch/main/graph/badge.svg?token=24628T3GQP" alt="Codecov">
  </a>
  <a href="https://github.com/ehennestad/openMINDS-MATLAB-GUI/actions/workflows/update.yml">
   <img src=".github/badges/tests.svg" alt="Run tests">
  </a>
  <a href="https://github.com/ehennestad/openMINDS-MATLAB-GUI/security/code-scanning">
   <img src=".github/badges/code_issues.svg" alt="Run Code Analyzer">
  </a>
  <a href="https://github.com/ehennestad/openMINDS-MATLAB-GUI/actions/workflows/run-codespell.yml?query=event%3Apush+branch%3Amain">
   <img src="https://github.com/ehennestad/openMINDS-MATLAB-GUI/actions/workflows/run-codespell.yml/badge.svg?branch=main" alt="Codespell">
  </a>
</h4>

<p align="center">
  <a href="#installation">Installation</a> •
  <a href="#getting-started">Getting Started</a> •
  <a href="#tutorials">Tutorials</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#acknowledgements">Acknowledgements</a>
</p>

---

A MATLAB graphical user interface (GUI) for openMINDS. This toolbox builds upon the [openMINDS_MATLAB](https://github.com/openMetadataInitiative/openMINDS_MATLAB) toolkit, offering interactive forms to streamline metadata entry."

## Requirements:
MATLAB 2023a or later

## Installation
1. Clone or download this repository
2. Navigate to the repository folder in MATLAB
3. Run `setup.m`

## Getting started
This is a very minimal example on how to try out this toolbox. More examples and interactive workflows will be added later.
```
% Create a filepath to a file for saving metadata
filePath = fullfile(userpath, "openMINDS_MATLAB", "demo", "datasetversion_gui.jsonld");

if ~isfile(filePath)
    dsv = openminds.core.DatasetVersion();
    collection = openminds.Collection();
    collection.save(filePath)
    mode = "create";
else
    collection = openminds.Collection(filePath);
    dsv = collection.list("DatasetVersion");
    mode = "modify";
end

dsv = om.uiCreateNewInstance(dsv, collection, "Mode", mode);

if ~isempty(dsv)
    collection.save(filePath)
end
```

## Tutorials
Todo

## Contributing
Todo

## Acknowledgements
Todo


