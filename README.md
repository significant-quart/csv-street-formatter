# csv-street-formatter

**Tool made for a friend to parse and format CSV files containing delivery manifests**

## Description

CSV files placed in the ``in`` folder are parsed and formatted according to user-defined routes. Each route contains a list of streets used to sort the input data. 

## Installation

1. Clone this repository
2. Install [Luvit](https://luvit.io/install.html)
3. Run ``lit install`` to install the required dependencies
4. Open ``config.json`` and ensure values are correct
5. Run ``make.bat`` (or ``lit make`` if on Linux)
6. Run the executable provided

## Example Usage

An example manifest may look like:

```csv
ID,ADDRESS,POSTCODE, COURIER, PRIORITY, METHOD
H00A0A0001234567 (R), 1 New Glen Avn, EH12 ABC, Parcelhub, NDAY, Standard
H00B0B0001234567 (R), 2 New Glen Avn, EH12 ABC, Parcelhub, NDAY, Standard
...
```

And an example route may look like

```
A
New Glen Avenue, New Glen Avn [DSC]
...

B
...
```
Letters specify zones which addresses are sorted into.

``[DSC]`` implies that the preceding street is sorted in descending order by house number.