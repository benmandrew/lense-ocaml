  $ for f in cases/*.ml; do echo "### $f"; lense-ocaml --json $f; done
  ### cases/exceptions.ml
  {
    "word_size": 64,
    "units": [
      {
        "file": "cases/exceptions.ml",
        "unit": "Exceptions",
        "types": [
          {
            "name": "Empty",
            "params": "",
            "keyword": "exception",
            "line": 1,
            "kind": "extension",
            "case": {
              "name": "Empty",
              "shape": {
                "kind": "block",
                "tag": 248,
                "size": 2,
                "extension_slot": true
              },
              "notes": []
            },
            "notes": []
          },
          {
            "name": "Error",
            "params": "",
            "keyword": "exception",
            "line": 2,
            "kind": "extension",
            "case": {
              "name": "Error",
              "shape": {
                "kind": "block",
                "tag": 0,
                "size": 3,
                "fields": [
                  {
                    "kind": "slot",
                    "constructor": "Error",
                    "type": "extension slot",
                    "mutable": false,
                    "word": {
                      "kind": "pointer",
                      "tag": 248,
                      "what": "extension slot"
                    }
                  },
                  {
                    "kind": "arg",
                    "type": "int",
                    "mutable": false,
                    "word": {
                      "kind": "immediate",
                      "why": "int"
                    }
                  },
                  {
                    "kind": "arg",
                    "type": "string",
                    "mutable": false,
                    "word": {
                      "kind": "pointer",
                      "tag": 252,
                      "what": "string"
                    }
                  }
                ]
              },
              "notes": []
            },
            "notes": []
          },
          {
            "name": "Detail",
            "params": "",
            "keyword": "exception",
            "line": 3,
            "kind": "extension",
            "case": {
              "name": "Detail",
              "shape": {
                "kind": "block",
                "tag": 0,
                "size": 3,
                "fields": [
                  {
                    "kind": "slot",
                    "constructor": "Detail",
                    "type": "extension slot",
                    "mutable": false,
                    "word": {
                      "kind": "pointer",
                      "tag": 248,
                      "what": "extension slot"
                    }
                  },
                  {
                    "kind": "label",
                    "name": "code",
                    "type": "int",
                    "mutable": false,
                    "word": {
                      "kind": "immediate",
                      "why": "int"
                    }
                  },
                  {
                    "kind": "label",
                    "name": "msg",
                    "type": "string",
                    "mutable": false,
                    "word": {
                      "kind": "pointer",
                      "tag": 252,
                      "what": "string"
                    }
                  }
                ]
              },
              "notes": []
            },
            "notes": []
          },
          {
            "name": "Again",
            "params": "",
            "keyword": "exception",
            "line": 4,
            "kind": "extension",
            "case": {
              "name": "Again",
              "shape": {
                "kind": "rebind",
                "of": "Empty"
              },
              "notes": []
            },
            "notes": []
          },
          {
            "name": "ext",
            "params": "",
            "keyword": "type",
            "line": 6,
            "kind": "open",
            "notes": []
          },
          {
            "name": "X1",
            "params": "",
            "keyword": "extension",
            "line": 7,
            "kind": "extension",
            "case": {
              "name": "X1",
              "shape": {
                "kind": "block",
                "tag": 248,
                "size": 2,
                "extension_slot": true
              },
              "notes": []
            },
            "notes": []
          },
          {
            "name": "X2",
            "params": "",
            "keyword": "extension",
            "line": 7,
            "kind": "extension",
            "case": {
              "name": "X2",
              "shape": {
                "kind": "block",
                "tag": 0,
                "size": 2,
                "fields": [
                  {
                    "kind": "slot",
                    "constructor": "X2",
                    "type": "extension slot",
                    "mutable": false,
                    "word": {
                      "kind": "pointer",
                      "tag": 248,
                      "what": "extension slot"
                    }
                  },
                  {
                    "kind": "arg",
                    "type": "int",
                    "mutable": false,
                    "word": {
                      "kind": "immediate",
                      "why": "int"
                    }
                  }
                ]
              },
              "notes": []
            },
            "notes": []
          },
          {
            "name": "X3",
            "params": "",
            "keyword": "extension",
            "line": 7,
            "kind": "extension",
            "case": {
              "name": "X3",
              "shape": {
                "kind": "block",
                "tag": 0,
                "size": 2,
                "fields": [
                  {
                    "kind": "slot",
                    "constructor": "X3",
                    "type": "extension slot",
                    "mutable": false,
                    "word": {
                      "kind": "pointer",
                      "tag": 248,
                      "what": "extension slot"
                    }
                  },
                  {
                    "kind": "arg",
                    "type": "float",
                    "mutable": false,
                    "word": {
                      "kind": "pointer",
                      "tag": 253,
                      "what": "boxed float"
                    }
                  }
                ]
              },
              "notes": []
            },
            "notes": []
          },
          {
            "name": "X4",
            "params": "",
            "keyword": "extension",
            "line": 8,
            "kind": "extension",
            "case": {
              "name": "X4",
              "shape": {
                "kind": "block",
                "tag": 0,
                "size": 2,
                "fields": [
                  {
                    "kind": "slot",
                    "constructor": "X4",
                    "type": "extension slot",
                    "mutable": false,
                    "word": {
                      "kind": "pointer",
                      "tag": 248,
                      "what": "extension slot"
                    }
                  },
                  {
                    "kind": "label",
                    "name": "r",
                    "type": "float",
                    "mutable": false,
                    "word": {
                      "kind": "pointer",
                      "tag": 253,
                      "what": "boxed float"
                    }
                  }
                ]
              },
              "notes": [
                "inline record: all fields are float, but inline records are never stored flat"
              ]
            },
            "notes": []
          },
          {
            "name": "res",
            "params": "'a",
            "keyword": "type",
            "line": 10,
            "kind": "open",
            "notes": []
          },
          {
            "name": "Ok_",
            "params": "",
            "keyword": "extension",
            "line": 11,
            "kind": "extension",
            "case": {
              "name": "Ok_",
              "shape": {
                "kind": "block",
                "tag": 0,
                "size": 2,
                "fields": [
                  {
                    "kind": "slot",
                    "constructor": "Ok_",
                    "type": "extension slot",
                    "mutable": false,
                    "word": {
                      "kind": "pointer",
                      "tag": 248,
                      "what": "extension slot"
                    }
                  },
                  {
                    "kind": "arg",
                    "type": "'a",
                    "mutable": false,
                    "word": {
                      "kind": "any",
                      "why": "type variable 'a"
                    }
                  }
                ]
              },
              "notes": []
            },
            "notes": []
          }
        ],
        "packages": [],
        "labels": []
      }
    ],
    "collisions": []
  }
  ### cases/packages.ml
  {
    "word_size": 64,
    "units": [
      {
        "file": "cases/packages.ml",
        "unit": "Packages",
        "types": [
          {
            "name": "entry",
            "params": "",
            "keyword": "type",
            "line": 10,
            "kind": "record",
            "shape": {
              "kind": "block",
              "tag": 0,
              "size": 2,
              "fields": [
                {
                  "kind": "label",
                  "name": "key",
                  "type": "int",
                  "mutable": false,
                  "word": {
                    "kind": "immediate",
                    "why": "int"
                  }
                },
                {
                  "kind": "label",
                  "name": "ops",
                  "type": "(module ORDERED with type t = int)",
                  "mutable": false,
                  "word": {
                    "kind": "pointer",
                    "tag": null,
                    "what": "first-class module"
                  }
                }
              ]
            },
            "notes": []
          },
          {
            "name": "Ints.Unordered",
            "params": "",
            "keyword": "exception",
            "line": 13,
            "kind": "extension",
            "case": {
              "name": "Unordered",
              "shape": {
                "kind": "block",
                "tag": 248,
                "size": 2,
                "extension_slot": true
              },
              "notes": []
            },
            "notes": []
          },
          {
            "name": "Ints.t",
            "params": "",
            "keyword": "type",
            "line": 14,
            "kind": "alias",
            "word": {
              "kind": "immediate",
              "why": "int"
            },
            "notes": []
          }
        ],
        "packages": [
          {
            "name": "ORDERED",
            "line": 10,
            "size": 4,
            "fields": [
              {
                "index": 0,
                "item": "value",
                "name": "name",
                "word": {
                  "kind": "pointer",
                  "tag": 252,
                  "what": "string"
                }
              },
              {
                "index": 1,
                "item": "value",
                "name": "compare",
                "word": {
                  "kind": "pointer",
                  "tag": 247,
                  "what": "closure"
                }
              },
              {
                "index": 2,
                "item": "module",
                "name": "Sub",
                "word": {
                  "kind": "pointer",
                  "tag": 0,
                  "what": "structure"
                }
              },
              {
                "index": 3,
                "item": "exception",
                "name": "Unordered",
                "word": {
                  "kind": "pointer",
                  "tag": 248,
                  "what": "extension slot"
                }
              }
            ],
            "no_field": [
              "type t",
              "external id"
            ]
          },
          {
            "name": "Shapes.SHAPE",
            "line": 32,
            "size": 2,
            "fields": [
              {
                "index": 0,
                "item": "value",
                "name": "area",
                "word": {
                  "kind": "pointer",
                  "tag": 253,
                  "what": "boxed float"
                }
              },
              {
                "index": 1,
                "item": "functor",
                "name": "Scale",
                "word": {
                  "kind": "pointer",
                  "tag": 247,
                  "what": "closure"
                }
              }
            ],
            "no_field": []
          },
          {
            "name": "EMPTY",
            "line": 39,
            "size": 0,
            "fields": [],
            "no_field": [
              "type t"
            ]
          }
        ],
        "labels": []
      }
    ],
    "collisions": []
  }
  ### cases/polyvariants.ml
  {
    "word_size": 64,
    "units": [
      {
        "file": "cases/polyvariants.ml",
        "unit": "Polyvariants",
        "types": [
          {
            "name": "colour",
            "params": "",
            "keyword": "type",
            "line": 1,
            "kind": "polymorphic_variant",
            "closed": true,
            "cases": [
              {
                "name": "`Red",
                "shape": {
                  "kind": "immediate",
                  "value": 4100401
                },
                "notes": []
              },
              {
                "name": "`Blue",
                "shape": {
                  "kind": "immediate",
                  "value": 737308346
                },
                "notes": []
              },
              {
                "name": "`Green",
                "shape": {
                  "kind": "immediate",
                  "value": 756711075
                },
                "notes": []
              }
            ],
            "notes": []
          },
          {
            "name": "event",
            "params": "",
            "keyword": "type",
            "line": 2,
            "kind": "polymorphic_variant",
            "closed": true,
            "cases": [
              {
                "name": "`Click",
                "shape": {
                  "kind": "block",
                  "tag": 0,
                  "size": 2,
                  "fields": [
                    {
                      "kind": "hash",
                      "hash": -611587032,
                      "type": "int",
                      "mutable": false,
                      "word": {
                        "kind": "immediate",
                        "why": "label hash"
                      }
                    },
                    {
                      "kind": "arg",
                      "type": "int * int",
                      "mutable": false,
                      "word": {
                        "kind": "pointer",
                        "tag": 0,
                        "what": "tuple"
                      }
                    }
                  ]
                },
                "notes": []
              },
              {
                "name": "`Key",
                "shape": {
                  "kind": "block",
                  "tag": 0,
                  "size": 2,
                  "fields": [
                    {
                      "kind": "hash",
                      "hash": 3752319,
                      "type": "int",
                      "mutable": false,
                      "word": {
                        "kind": "immediate",
                        "why": "label hash"
                      }
                    },
                    {
                      "kind": "arg",
                      "type": "char",
                      "mutable": false,
                      "word": {
                        "kind": "immediate",
                        "why": "char"
                      }
                    }
                  ]
                },
                "notes": []
              },
              {
                "name": "`Quit",
                "shape": {
                  "kind": "immediate",
                  "value": 904096751
                },
                "notes": []
              }
            ],
            "notes": []
          },
          {
            "name": "opened",
            "params": "'a",
            "keyword": "type",
            "line": 3,
            "kind": "polymorphic_variant",
            "closed": false,
            "cases": [
              {
                "name": "`A",
                "shape": {
                  "kind": "immediate",
                  "value": 65
                },
                "notes": []
              },
              {
                "name": "`B",
                "shape": {
                  "kind": "block",
                  "tag": 0,
                  "size": 2,
                  "fields": [
                    {
                      "kind": "hash",
                      "hash": 66,
                      "type": "int",
                      "mutable": false,
                      "word": {
                        "kind": "immediate",
                        "why": "label hash"
                      }
                    },
                    {
                      "kind": "arg",
                      "type": "int",
                      "mutable": false,
                      "word": {
                        "kind": "immediate",
                        "why": "int"
                      }
                    }
                  ]
                },
                "notes": []
              }
            ],
            "notes": []
          },
          {
            "name": "sub",
            "params": "'a",
            "keyword": "type",
            "line": 4,
            "kind": "polymorphic_variant",
            "closed": true,
            "cases": [
              {
                "name": "`A",
                "shape": {
                  "kind": "immediate",
                  "value": 65
                },
                "notes": []
              },
              {
                "name": "`B",
                "shape": {
                  "kind": "block",
                  "tag": 0,
                  "size": 2,
                  "fields": [
                    {
                      "kind": "hash",
                      "hash": 66,
                      "type": "int",
                      "mutable": false,
                      "word": {
                        "kind": "immediate",
                        "why": "label hash"
                      }
                    },
                    {
                      "kind": "arg",
                      "type": "int",
                      "mutable": false,
                      "word": {
                        "kind": "immediate",
                        "why": "int"
                      }
                    }
                  ]
                },
                "notes": []
              }
            ],
            "notes": []
          },
          {
            "name": "both",
            "params": "",
            "keyword": "type",
            "line": 5,
            "kind": "polymorphic_variant",
            "closed": true,
            "cases": [
              {
                "name": "`Click",
                "shape": {
                  "kind": "block",
                  "tag": 0,
                  "size": 2,
                  "fields": [
                    {
                      "kind": "hash",
                      "hash": -611587032,
                      "type": "int",
                      "mutable": false,
                      "word": {
                        "kind": "immediate",
                        "why": "label hash"
                      }
                    },
                    {
                      "kind": "arg",
                      "type": "int * int",
                      "mutable": false,
                      "word": {
                        "kind": "pointer",
                        "tag": 0,
                        "what": "tuple"
                      }
                    }
                  ]
                },
                "notes": []
              },
              {
                "name": "`Key",
                "shape": {
                  "kind": "block",
                  "tag": 0,
                  "size": 2,
                  "fields": [
                    {
                      "kind": "hash",
                      "hash": 3752319,
                      "type": "int",
                      "mutable": false,
                      "word": {
                        "kind": "immediate",
                        "why": "label hash"
                      }
                    },
                    {
                      "kind": "arg",
                      "type": "char",
                      "mutable": false,
                      "word": {
                        "kind": "immediate",
                        "why": "char"
                      }
                    }
                  ]
                },
                "notes": []
              },
              {
                "name": "`Red",
                "shape": {
                  "kind": "immediate",
                  "value": 4100401
                },
                "notes": []
              },
              {
                "name": "`Blue",
                "shape": {
                  "kind": "immediate",
                  "value": 737308346
                },
                "notes": []
              },
              {
                "name": "`Green",
                "shape": {
                  "kind": "immediate",
                  "value": 756711075
                },
                "notes": []
              },
              {
                "name": "`Quit",
                "shape": {
                  "kind": "immediate",
                  "value": 904096751
                },
                "notes": []
              }
            ],
            "notes": []
          },
          {
            "name": "nested",
            "params": "",
            "keyword": "type",
            "line": 6,
            "kind": "record",
            "shape": {
              "kind": "block",
              "tag": 0,
              "size": 2,
              "fields": [
                {
                  "kind": "label",
                  "name": "c",
                  "type": "colour",
                  "mutable": false,
                  "word": {
                    "kind": "immediate",
                    "why": "constant polymorphic variant"
                  }
                },
                {
                  "kind": "label",
                  "name": "e",
                  "type": "event",
                  "mutable": false,
                  "word": {
                    "kind": "any",
                    "why": "polymorphic variant"
                  }
                }
              ]
            },
            "notes": []
          }
        ],
        "packages": [],
        "labels": [
          {
            "label": "Red",
            "hash": 4100401,
            "file": "cases/polyvariants.ml",
            "line": 1
          },
          {
            "label": "Green",
            "hash": 756711075,
            "file": "cases/polyvariants.ml",
            "line": 1
          },
          {
            "label": "Blue",
            "hash": 737308346,
            "file": "cases/polyvariants.ml",
            "line": 1
          },
          {
            "label": "Key",
            "hash": 3752319,
            "file": "cases/polyvariants.ml",
            "line": 2
          },
          {
            "label": "Click",
            "hash": -611587032,
            "file": "cases/polyvariants.ml",
            "line": 2
          },
          {
            "label": "Quit",
            "hash": 904096751,
            "file": "cases/polyvariants.ml",
            "line": 2
          },
          {
            "label": "A",
            "hash": 65,
            "file": "cases/polyvariants.ml",
            "line": 3
          },
          {
            "label": "B",
            "hash": 66,
            "file": "cases/polyvariants.ml",
            "line": 3
          },
          {
            "label": "A",
            "hash": 65,
            "file": "cases/polyvariants.ml",
            "line": 4
          },
          {
            "label": "B",
            "hash": 66,
            "file": "cases/polyvariants.ml",
            "line": 4
          },
          {
            "label": "Foo",
            "hash": 3505894,
            "file": "cases/polyvariants.ml",
            "line": 8
          },
          {
            "label": "Bar",
            "hash": 3303859,
            "file": "cases/polyvariants.ml",
            "line": 8
          }
        ]
      }
    ],
    "collisions": []
  }
  ### cases/records.ml
  {
    "word_size": 64,
    "units": [
      {
        "file": "cases/records.ml",
        "unit": "Records",
        "types": [
          {
            "name": "r",
            "params": "",
            "keyword": "type",
            "line": 1,
            "kind": "record",
            "shape": {
              "kind": "block",
              "tag": 0,
              "size": 2,
              "fields": [
                {
                  "kind": "label",
                  "name": "a",
                  "type": "int",
                  "mutable": false,
                  "word": {
                    "kind": "immediate",
                    "why": "int"
                  }
                },
                {
                  "kind": "label",
                  "name": "b",
                  "type": "float",
                  "mutable": false,
                  "word": {
                    "kind": "pointer",
                    "tag": 253,
                    "what": "boxed float"
                  }
                }
              ]
            },
            "notes": []
          },
          {
            "name": "point",
            "params": "",
            "keyword": "type",
            "line": 2,
            "kind": "record",
            "shape": {
              "kind": "block",
              "tag": 254,
              "size": 2,
              "flat_float": true,
              "fields": [
                {
                  "kind": "label",
                  "name": "x",
                  "type": "float",
                  "mutable": false,
                  "word": {
                    "kind": "double"
                  }
                },
                {
                  "kind": "label",
                  "name": "y",
                  "type": "float",
                  "mutable": false,
                  "word": {
                    "kind": "double"
                  }
                }
              ]
            },
            "notes": []
          },
          {
            "name": "mpoint",
            "params": "",
            "keyword": "type",
            "line": 3,
            "kind": "record",
            "shape": {
              "kind": "block",
              "tag": 254,
              "size": 2,
              "flat_float": true,
              "fields": [
                {
                  "kind": "label",
                  "name": "mx",
                  "type": "float",
                  "mutable": true,
                  "word": {
                    "kind": "double"
                  }
                },
                {
                  "kind": "label",
                  "name": "my",
                  "type": "float",
                  "mutable": false,
                  "word": {
                    "kind": "double"
                  }
                }
              ]
            },
            "notes": []
          },
          {
            "name": "single_float",
            "params": "",
            "keyword": "type",
            "line": 4,
            "kind": "record",
            "shape": {
              "kind": "block",
              "tag": 254,
              "size": 1,
              "flat_float": true,
              "fields": [
                {
                  "kind": "label",
                  "name": "f",
                  "type": "float",
                  "mutable": false,
                  "word": {
                    "kind": "double"
                  }
                }
              ]
            },
            "notes": []
          },
          {
            "name": "wrapped",
            "params": "",
            "keyword": "type",
            "line": 5,
            "kind": "record",
            "shape": {
              "kind": "unboxed",
              "field": {
                "kind": "label",
                "name": "u",
                "type": "string",
                "mutable": false,
                "word": {
                  "kind": "pointer",
                  "tag": 252,
                  "what": "string"
                }
              }
            },
            "notes": []
          },
          {
            "name": "id",
            "params": "",
            "keyword": "type",
            "line": 6,
            "kind": "variant",
            "cases": [
              {
                "name": "Id",
                "shape": {
                  "kind": "unboxed",
                  "field": {
                    "kind": "arg",
                    "type": "int",
                    "mutable": false,
                    "word": {
                      "kind": "immediate",
                      "why": "int"
                    }
                  }
                },
                "notes": []
              }
            ],
            "notes": []
          },
          {
            "name": "fbox",
            "params": "",
            "keyword": "type",
            "line": 7,
            "kind": "record",
            "shape": {
              "kind": "unboxed",
              "field": {
                "kind": "label",
                "name": "uf",
                "type": "float",
                "mutable": false,
                "word": {
                  "kind": "pointer",
                  "tag": 253,
                  "what": "boxed float"
                }
              }
            },
            "notes": []
          },
          {
            "name": "poly",
            "params": "",
            "keyword": "type",
            "line": 8,
            "kind": "record",
            "shape": {
              "kind": "block",
              "tag": 0,
              "size": 2,
              "fields": [
                {
                  "kind": "label",
                  "name": "apply",
                  "type": "'a. 'a -> 'a",
                  "mutable": false,
                  "word": {
                    "kind": "pointer",
                    "tag": 247,
                    "what": "closure"
                  }
                },
                {
                  "kind": "label",
                  "name": "n",
                  "type": "int",
                  "mutable": false,
                  "word": {
                    "kind": "immediate",
                    "why": "int"
                  }
                }
              ]
            },
            "notes": []
          },
          {
            "name": "cell",
            "params": "'a",
            "keyword": "type",
            "line": 9,
            "kind": "record",
            "shape": {
              "kind": "block",
              "tag": 0,
              "size": 2,
              "fields": [
                {
                  "kind": "label",
                  "name": "contents",
                  "type": "'a",
                  "mutable": true,
                  "word": {
                    "kind": "any",
                    "why": "type variable 'a"
                  }
                },
                {
                  "kind": "label",
                  "name": "count",
                  "type": "int",
                  "mutable": false,
                  "word": {
                    "kind": "immediate",
                    "why": "int"
                  }
                }
              ]
            },
            "notes": []
          },
          {
            "name": "inline",
            "params": "",
            "keyword": "type",
            "line": 11,
            "kind": "variant",
            "cases": [
              {
                "name": "I0",
                "shape": {
                  "kind": "immediate",
                  "value": 0
                },
                "notes": []
              },
              {
                "name": "I1",
                "shape": {
                  "kind": "block",
                  "tag": 0,
                  "size": 1,
                  "fields": [
                    {
                      "kind": "arg",
                      "type": "int",
                      "mutable": false,
                      "word": {
                        "kind": "immediate",
                        "why": "int"
                      }
                    }
                  ]
                },
                "notes": []
              },
              {
                "name": "I2",
                "shape": {
                  "kind": "block",
                  "tag": 1,
                  "size": 2,
                  "fields": [
                    {
                      "kind": "label",
                      "name": "ix",
                      "type": "int",
                      "mutable": false,
                      "word": {
                        "kind": "immediate",
                        "why": "int"
                      }
                    },
                    {
                      "kind": "label",
                      "name": "iy",
                      "type": "float",
                      "mutable": false,
                      "word": {
                        "kind": "pointer",
                        "tag": 253,
                        "what": "boxed float"
                      }
                    }
                  ]
                },
                "notes": []
              },
              {
                "name": "I3",
                "shape": {
                  "kind": "block",
                  "tag": 2,
                  "size": 2,
                  "fields": [
                    {
                      "kind": "label",
                      "name": "f1",
                      "type": "float",
                      "mutable": false,
                      "word": {
                        "kind": "pointer",
                        "tag": 253,
                        "what": "boxed float"
                      }
                    },
                    {
                      "kind": "label",
                      "name": "f2",
                      "type": "float",
                      "mutable": false,
                      "word": {
                        "kind": "pointer",
                        "tag": 253,
                        "what": "boxed float"
                      }
                    }
                  ]
                },
                "notes": [
                  "inline record: all fields are float, but inline records are never stored flat"
                ]
              }
            ],
            "notes": []
          },
          {
            "name": "iu",
            "params": "",
            "keyword": "type",
            "line": 17,
            "kind": "variant",
            "cases": [
              {
                "name": "IU",
                "shape": {
                  "kind": "unboxed",
                  "field": {
                    "kind": "label",
                    "name": "iu",
                    "type": "int",
                    "mutable": false,
                    "word": {
                      "kind": "immediate",
                      "why": "int"
                    }
                  }
                },
                "notes": []
              }
            ],
            "notes": []
          },
          {
            "name": "uses",
            "params": "",
            "keyword": "type",
            "line": 19,
            "kind": "record",
            "shape": {
              "kind": "block",
              "tag": 0,
              "size": 8,
              "fields": [
                {
                  "kind": "label",
                  "name": "t",
                  "type": "inline",
                  "mutable": false,
                  "word": {
                    "kind": "any",
                    "why": "inline"
                  }
                },
                {
                  "kind": "label",
                  "name": "ids",
                  "type": "id list",
                  "mutable": false,
                  "word": {
                    "kind": "any",
                    "why": "list"
                  }
                },
                {
                  "kind": "label",
                  "name": "arr",
                  "type": "float array",
                  "mutable": false,
                  "word": {
                    "kind": "pointer",
                    "tag": null,
                    "what": "float array (Double_array_tag 254 unless empty)"
                  }
                },
                {
                  "kind": "label",
                  "name": "iarr",
                  "type": "int array",
                  "mutable": false,
                  "word": {
                    "kind": "pointer",
                    "tag": 0,
                    "what": "array"
                  }
                },
                {
                  "kind": "label",
                  "name": "opt",
                  "type": "int option",
                  "mutable": false,
                  "word": {
                    "kind": "any",
                    "why": "option"
                  }
                },
                {
                  "kind": "label",
                  "name": "big",
                  "type": "int64",
                  "mutable": false,
                  "word": {
                    "kind": "pointer",
                    "tag": 255,
                    "what": "custom block"
                  }
                },
                {
                  "kind": "label",
                  "name": "ch",
                  "type": "char",
                  "mutable": false,
                  "word": {
                    "kind": "immediate",
                    "why": "char"
                  }
                },
                {
                  "kind": "label",
                  "name": "lz",
                  "type": "int Lazy.t",
                  "mutable": false,
                  "word": {
                    "kind": "any",
                    "why": "lazy value"
                  }
                }
              ]
            },
            "notes": []
          }
        ],
        "packages": [],
        "labels": []
      }
    ],
    "collisions": []
  }
  ### cases/variants.ml
  {
    "word_size": 64,
    "units": [
      {
        "file": "cases/variants.ml",
        "unit": "Variants",
        "types": [
          {
            "name": "t",
            "params": "",
            "keyword": "type",
            "line": 1,
            "kind": "variant",
            "cases": [
              {
                "name": "A",
                "shape": {
                  "kind": "immediate",
                  "value": 0
                },
                "notes": []
              },
              {
                "name": "B",
                "shape": {
                  "kind": "block",
                  "tag": 0,
                  "size": 1,
                  "fields": [
                    {
                      "kind": "arg",
                      "type": "int",
                      "mutable": false,
                      "word": {
                        "kind": "immediate",
                        "why": "int"
                      }
                    }
                  ]
                },
                "notes": []
              },
              {
                "name": "C",
                "shape": {
                  "kind": "immediate",
                  "value": 1
                },
                "notes": []
              },
              {
                "name": "D",
                "shape": {
                  "kind": "block",
                  "tag": 1,
                  "size": 1,
                  "fields": [
                    {
                      "kind": "arg",
                      "type": "string",
                      "mutable": false,
                      "word": {
                        "kind": "pointer",
                        "tag": 252,
                        "what": "string"
                      }
                    }
                  ]
                },
                "notes": []
              }
            ],
            "notes": []
          },
          {
            "name": "shape",
            "params": "",
            "keyword": "type",
            "line": 3,
            "kind": "variant",
            "cases": [
              {
                "name": "Circle",
                "shape": {
                  "kind": "block",
                  "tag": 0,
                  "size": 1,
                  "fields": [
                    {
                      "kind": "arg",
                      "type": "float",
                      "mutable": false,
                      "word": {
                        "kind": "pointer",
                        "tag": 253,
                        "what": "boxed float"
                      }
                    }
                  ]
                },
                "notes": []
              },
              {
                "name": "Rect",
                "shape": {
                  "kind": "block",
                  "tag": 1,
                  "size": 2,
                  "fields": [
                    {
                      "kind": "arg",
                      "type": "float",
                      "mutable": false,
                      "word": {
                        "kind": "pointer",
                        "tag": 253,
                        "what": "boxed float"
                      }
                    },
                    {
                      "kind": "arg",
                      "type": "float",
                      "mutable": false,
                      "word": {
                        "kind": "pointer",
                        "tag": 253,
                        "what": "boxed float"
                      }
                    }
                  ]
                },
                "notes": []
              },
              {
                "name": "Point",
                "shape": {
                  "kind": "immediate",
                  "value": 0
                },
                "notes": []
              }
            ],
            "notes": []
          },
          {
            "name": "nested",
            "params": "",
            "keyword": "type",
            "line": 5,
            "kind": "variant",
            "cases": [
              {
                "name": "T",
                "shape": {
                  "kind": "block",
                  "tag": 0,
                  "size": 1,
                  "fields": [
                    {
                      "kind": "arg",
                      "type": "int * int",
                      "mutable": false,
                      "word": {
                        "kind": "pointer",
                        "tag": 0,
                        "what": "tuple"
                      }
                    }
                  ]
                },
                "notes": []
              },
              {
                "name": "T2",
                "shape": {
                  "kind": "block",
                  "tag": 1,
                  "size": 2,
                  "fields": [
                    {
                      "kind": "arg",
                      "type": "int",
                      "mutable": false,
                      "word": {
                        "kind": "immediate",
                        "why": "int"
                      }
                    },
                    {
                      "kind": "arg",
                      "type": "int",
                      "mutable": false,
                      "word": {
                        "kind": "immediate",
                        "why": "int"
                      }
                    }
                  ]
                },
                "notes": []
              }
            ],
            "notes": []
          },
          {
            "name": "tree",
            "params": "'a",
            "keyword": "type",
            "line": 7,
            "kind": "variant",
            "cases": [
              {
                "name": "Leaf",
                "shape": {
                  "kind": "immediate",
                  "value": 0
                },
                "notes": []
              },
              {
                "name": "Node",
                "shape": {
                  "kind": "block",
                  "tag": 0,
                  "size": 3,
                  "fields": [
                    {
                      "kind": "arg",
                      "type": "'a tree",
                      "mutable": false,
                      "word": {
                        "kind": "any",
                        "why": "tree"
                      }
                    },
                    {
                      "kind": "arg",
                      "type": "'a",
                      "mutable": false,
                      "word": {
                        "kind": "any",
                        "why": "type variable 'a"
                      }
                    },
                    {
                      "kind": "arg",
                      "type": "'a tree",
                      "mutable": false,
                      "word": {
                        "kind": "any",
                        "why": "tree"
                      }
                    }
                  ]
                },
                "notes": []
              }
            ],
            "notes": []
          },
          {
            "name": "empty",
            "params": "",
            "keyword": "type",
            "line": 9,
            "kind": "variant",
            "cases": [],
            "notes": []
          },
          {
            "name": "expr",
            "params": "_",
            "keyword": "type",
            "line": 11,
            "kind": "variant",
            "cases": [
              {
                "name": "Int",
                "shape": {
                  "kind": "block",
                  "tag": 0,
                  "size": 1,
                  "fields": [
                    {
                      "kind": "arg",
                      "type": "int",
                      "mutable": false,
                      "word": {
                        "kind": "immediate",
                        "why": "int"
                      }
                    }
                  ]
                },
                "notes": []
              },
              {
                "name": "Bool",
                "shape": {
                  "kind": "block",
                  "tag": 1,
                  "size": 1,
                  "fields": [
                    {
                      "kind": "arg",
                      "type": "bool",
                      "mutable": false,
                      "word": {
                        "kind": "immediate",
                        "why": "bool"
                      }
                    }
                  ]
                },
                "notes": []
              },
              {
                "name": "Pair",
                "shape": {
                  "kind": "block",
                  "tag": 2,
                  "size": 2,
                  "fields": [
                    {
                      "kind": "arg",
                      "type": "'a expr",
                      "mutable": false,
                      "word": {
                        "kind": "any",
                        "why": "expr"
                      }
                    },
                    {
                      "kind": "arg",
                      "type": "'b expr",
                      "mutable": false,
                      "word": {
                        "kind": "any",
                        "why": "expr"
                      }
                    }
                  ]
                },
                "notes": []
              },
              {
                "name": "Hide",
                "shape": {
                  "kind": "block",
                  "tag": 3,
                  "size": 2,
                  "fields": [
                    {
                      "kind": "arg",
                      "type": "'a",
                      "mutable": false,
                      "word": {
                        "kind": "any",
                        "why": "type variable 'a"
                      }
                    },
                    {
                      "kind": "arg",
                      "type": "'a -> string",
                      "mutable": false,
                      "word": {
                        "kind": "pointer",
                        "tag": 247,
                        "what": "closure"
                      }
                    }
                  ]
                },
                "notes": [
                  "existential 'a: stored as uniform values"
                ]
              },
              {
                "name": "Unit",
                "shape": {
                  "kind": "immediate",
                  "value": 0
                },
                "notes": []
              }
            ],
            "notes": [
              "GADT: type indices are erased, so the constructors are numbered as in an ordinary variant"
            ]
          }
        ],
        "packages": [],
        "labels": []
      }
    ],
    "collisions": []
  }
