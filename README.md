# mim

This repository is a 'mirror' of the NPfIT Messaging Implementation Manual, which contains standards and work which is now over 20 years old. Older versions of the MIM have been consigned to the National Archives. The 'latest' version of the MIM (7.2.02, dating from 2008 and branded 'NPfIT') is not in the National Archives but is included in this repository.

I have used LLM assistance to create human-readable derivative documentation from the original MIM, which is in a very difficult format to read and understand. The original MIM is in HTML format, but it is not well-structured or easy to navigate. The derivative documentation is intended to be more user-friendly and accessible, while still preserving the technical details and specifications of the original MIM.

## GP2GP

GP2GP is still in use across the English NHS, and is a system for transferring patient records between GP practices when a patient moves. The MIM contains the specifications for GP2GP, and the derivative documentation includes a section on GP2GP that explains how it works and how it is implemented. For more information on GP2GP, see [gp2gp.md](gp2gp.md)

### License

The MIM carries **NHS (Crown) Copyright** — `Readme.txt` states: _"Copyright UK National Health Service. NHS copyright applied to materials other than those general elements of HL7 included in these packages."_ The underlying HL7 v3 material is © 2002–2004 Health Level Seven, Incorporated. Some external documents within the MIM are additionally marked "Restricted".

No open licence (Open Government Licence, Creative Commons, etc.) has been applied to this material. This repository is published on the presumption that making a 20-year-old, publicly-available technical specification accessible in a usable format does not constitute meaningful harm, and that the public interest in NHS interoperability standards being readable outweighs any theoretical copyright concern. If you are the rights holder and disagree, please open an issue.

### References

#### MIM URLs on the National Archives

<https://webarchive.nationalarchives.gov.uk/ukgwa/20250306140946/https:/data.developer.nhs.uk/dms/mim/6.3.01/Index.htm>
<https://webarchive.nationalarchives.gov.uk/ukgwa/20250306135910/https:/data.developer.nhs.uk/dms/mim/3.1.09/Index.htm>
<https://webarchive.nationalarchives.gov.uk/ukgwa/20250306140715/https:/data.developer.nhs.uk/dms/mim/4.2.00/Index.htm>

This mim repo contains the entire downloaded LATEST MIM - MIM 7.2.02 (Publish) which is not in the national archives.

Incredibly this system (GP2GP) is still in use albeit seemingly no longer developed. New GP system suppliers would have to implement GP2GP using these archaic specs.

### GitHub Pages

This repo is served as a static site via GitHub Pages. Two files were added to make this work that are not part of the original MIM:

- **`index.html`** — the original entry point is `Index.htm`, which GitHub Pages' Linux servers do not serve automatically (filenames are case-sensitive and the default document must be lowercase `index.html`). This file is an exact copy of `Index.htm`'s frameset.
- **`.nojekyll`** — an empty file that tells GitHub Pages to skip Jekyll processing. Without it, Jekyll silently drops `.htm` files and can corrupt internal links.

**Note on character encoding:** all MIM HTML files are encoded as `windows-1252` (legacy Windows Latin-1). Modern browsers detect this correctly via the `<meta charset>` declarations in each file, but if you see garbled characters (e.g. © symbols, em-dashes, curly quotes) your browser may not be honouring the declared charset. This is a quirk of the original MIM files and is not something this repository can easily fix without re-encoding ~thousands of HTML files.
