  $ for f in cases/*.ml cases/*.mli; do echo "### $f"; lense-ocaml --json $f; done
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
                "extension_slot": true,
                "cost": null
              },
              "notes": [],
              "range": {"line": 1, "column": 0, "end_line": 1, "end_column": 15}
            },
            "notes": [],
            "range": {"line": 1, "column": 0, "end_line": 1, "end_column": 15}
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
                    },
                    "owns": {
                      "words": [0],
                      "range": false,
                      "not_counted": [],
                      "nodes": false
                    },
                    "range": null
                  },
                  {
                    "kind": "arg",
                    "type": "int",
                    "mutable": false,
                    "word": {
                      "kind": "immediate",
                      "why": "int"
                    },
                    "owns": {
                      "words": [0],
                      "range": false,
                      "not_counted": [],
                      "nodes": false
                    },
                    "range": {"line": 2, "column": 19, "end_line": 2, "end_column": 22}
                  },
                  {
                    "kind": "arg",
                    "type": "string",
                    "mutable": false,
                    "word": {
                      "kind": "pointer",
                      "tag": 252,
                      "what": "string"
                    },
                    "owns": {
                      "words": [0],
                      "range": false,
                      "not_counted": [
                        {
                          "what": "string",
                          "per_node": null
                        }
                      ],
                      "nodes": false
                    },
                    "range": {"line": 2, "column": 25, "end_line": 2, "end_column": 31}
                  }
                ],
                "cost": {
                  "words": [4],
                  "range": false,
                  "not_counted": [
                    {
                      "what": "string",
                      "per_node": null
                    }
                  ],
                  "nodes": false
                }
              },
              "notes": [],
              "range": {"line": 2, "column": 0, "end_line": 2, "end_column": 31}
            },
            "notes": [],
            "range": {"line": 2, "column": 0, "end_line": 2, "end_column": 31}
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
                    },
                    "owns": {
                      "words": [0],
                      "range": false,
                      "not_counted": [],
                      "nodes": false
                    },
                    "range": null
                  },
                  {
                    "kind": "label",
                    "name": "code",
                    "type": "int",
                    "mutable": false,
                    "word": {
                      "kind": "immediate",
                      "why": "int"
                    },
                    "owns": {
                      "words": [0],
                      "range": false,
                      "not_counted": [],
                      "nodes": false
                    },
                    "range": {"line": 3, "column": 22, "end_line": 3, "end_column": 33}
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
                    },
                    "owns": {
                      "words": [0],
                      "range": false,
                      "not_counted": [
                        {
                          "what": "string",
                          "per_node": null
                        }
                      ],
                      "nodes": false
                    },
                    "range": {"line": 3, "column": 34, "end_line": 3, "end_column": 46}
                  }
                ],
                "cost": {
                  "words": [4],
                  "range": false,
                  "not_counted": [
                    {
                      "what": "string",
                      "per_node": null
                    }
                  ],
                  "nodes": false
                }
              },
              "notes": [],
              "range": {"line": 3, "column": 0, "end_line": 3, "end_column": 48}
            },
            "notes": [],
            "range": {"line": 3, "column": 0, "end_line": 3, "end_column": 48}
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
                "of": "Empty",
                "cost": null
              },
              "notes": [],
              "range": {"line": 4, "column": 0, "end_line": 4, "end_column": 23}
            },
            "notes": [],
            "range": {"line": 4, "column": 0, "end_line": 4, "end_column": 23}
          },
          {
            "name": "ext",
            "params": "",
            "keyword": "type",
            "line": 6,
            "kind": "open",
            "notes": [],
            "range": {"line": 6, "column": 0, "end_line": 6, "end_column": 13}
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
                "extension_slot": true,
                "cost": null
              },
              "notes": [],
              "range": {"line": 7, "column": 12, "end_line": 7, "end_column": 14}
            },
            "notes": [],
            "range": {"line": 7, "column": 12, "end_line": 7, "end_column": 14}
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
                    },
                    "owns": {
                      "words": [0],
                      "range": false,
                      "not_counted": [],
                      "nodes": false
                    },
                    "range": null
                  },
                  {
                    "kind": "arg",
                    "type": "int",
                    "mutable": false,
                    "word": {
                      "kind": "immediate",
                      "why": "int"
                    },
                    "owns": {
                      "words": [0],
                      "range": false,
                      "not_counted": [],
                      "nodes": false
                    },
                    "range": {"line": 7, "column": 23, "end_line": 7, "end_column": 26}
                  }
                ],
                "cost": {
                  "words": [3],
                  "range": false,
                  "not_counted": [],
                  "nodes": false
                }
              },
              "notes": [],
              "range": {"line": 7, "column": 15, "end_line": 7, "end_column": 26}
            },
            "notes": [],
            "range": {"line": 7, "column": 15, "end_line": 7, "end_column": 26}
          },
          {
            "name": "Ask",
            "params": "",
            "keyword": "extension",
            "line": 10,
            "kind": "extension",
            "case": {
              "name": "Ask",
              "shape": {
                "kind": "block",
                "tag": 248,
                "size": 2,
                "extension_slot": true,
                "cost": null
              },
              "notes": [],
              "range": {"line": 10, "column": 19, "end_line": 10, "end_column": 37}
            },
            "notes": [],
            "range": {"line": 10, "column": 19, "end_line": 10, "end_column": 37}
          },
          {
            "name": "Tell",
            "params": "",
            "keyword": "extension",
            "line": 10,
            "kind": "extension",
            "case": {
              "name": "Tell",
              "shape": {
                "kind": "block",
                "tag": 0,
                "size": 2,
                "fields": [
                  {
                    "kind": "slot",
                    "constructor": "Tell",
                    "type": "extension slot",
                    "mutable": false,
                    "word": {
                      "kind": "pointer",
                      "tag": 248,
                      "what": "extension slot"
                    },
                    "owns": {
                      "words": [0],
                      "range": false,
                      "not_counted": [],
                      "nodes": false
                    },
                    "range": null
                  },
                  {
                    "kind": "arg",
                    "type": "string",
                    "mutable": false,
                    "word": {
                      "kind": "pointer",
                      "tag": 252,
                      "what": "string"
                    },
                    "owns": {
                      "words": [0],
                      "range": false,
                      "not_counted": [
                        {
                          "what": "string",
                          "per_node": null
                        }
                      ],
                      "nodes": false
                    },
                    "range": {"line": 10, "column": 47, "end_line": 10, "end_column": 53}
                  }
                ],
                "cost": {
                  "words": [3],
                  "range": false,
                  "not_counted": [
                    {
                      "what": "string",
                      "per_node": null
                    }
                  ],
                  "nodes": false
                }
              },
              "notes": [],
              "range": {"line": 10, "column": 38, "end_line": 10, "end_column": 70}
            },
            "notes": [],
            "range": {"line": 10, "column": 38, "end_line": 10, "end_column": 70}
          }
        ],
        "packages": [],
        "labels": [],
        "values": {
          "closures": [
            {
              "backend": "native code",
              "config": "Closure, without flambda",
              "closures": []
            }
          ],
          "lazy": [],
          "objects": []
        }
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
            "line": 15,
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
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  },
                  "range": {"line": 15, "column": 15, "end_line": 15, "end_column": 25}
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
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [
                      {
                        "what": "first-class module",
                        "per_node": null
                      }
                    ],
                    "nodes": false
                  },
                  "range": {"line": 15, "column": 26, "end_line": 15, "end_column": 66}
                }
              ],
              "cost": {
                "words": [3],
                "range": false,
                "not_counted": [
                  {
                    "what": "first-class module",
                    "per_node": null
                  }
                ],
                "nodes": false
              }
            },
            "notes": [],
            "range": {"line": 15, "column": 0, "end_line": 15, "end_column": 68}
          },
          {
            "name": "Ints.Unordered",
            "params": "",
            "keyword": "exception",
            "line": 20,
            "kind": "extension",
            "case": {
              "name": "Unordered",
              "shape": {
                "kind": "block",
                "tag": 248,
                "size": 2,
                "extension_slot": true,
                "cost": null
              },
              "notes": [],
              "range": {"line": 20, "column": 2, "end_line": 20, "end_column": 21}
            },
            "notes": [],
            "range": {"line": 20, "column": 2, "end_line": 20, "end_column": 21}
          },
          {
            "name": "Ints.t",
            "params": "",
            "keyword": "type",
            "line": 22,
            "kind": "alias",
            "word": {
              "kind": "immediate",
              "why": "int"
            },
            "notes": [],
            "range": {"line": 22, "column": 2, "end_line": 22, "end_column": 14}
          }
        ],
        "packages": [
          {
            "name": "ORDERED",
            "line": 15,
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
                },
                "range": {"line": 4, "column": 2, "end_line": 4, "end_column": 19}
              },
              {
                "index": 1,
                "item": "value",
                "name": "compare",
                "word": {
                  "kind": "pointer",
                  "tag": null,
                  "what": "closure, Closure_tag 247 or Infix_tag 249"
                },
                "range": {"line": 5, "column": 2, "end_line": 5, "end_column": 29}
              },
              {
                "index": 2,
                "item": "module",
                "name": "Sub",
                "word": {
                  "kind": "pointer",
                  "tag": 0,
                  "what": "structure"
                },
                "range": {"line": 8, "column": 2, "end_line": 10, "end_column": 5}
              },
              {
                "index": 3,
                "item": "exception",
                "name": "Unordered",
                "word": {
                  "kind": "pointer",
                  "tag": 248,
                  "what": "extension slot"
                },
                "range": {"line": 12, "column": 2, "end_line": 12, "end_column": 21}
              }
            ],
            "no_field": [
              "type t",
              "external id"
            ],
            "range": {"line": 1, "column": 0, "end_line": 13, "end_column": 3}
          },
          {
            "name": "Shapes.SHAPE",
            "line": 56,
            "size": 3,
            "fields": [
              {
                "index": 0,
                "item": "value",
                "name": "area",
                "word": {
                  "kind": "pointer",
                  "tag": 253,
                  "what": "boxed float"
                },
                "range": {"line": 41, "column": 4, "end_line": 41, "end_column": 20}
              },
              {
                "index": 1,
                "item": "class",
                "name": "drawing",
                "word": {
                  "kind": "pointer",
                  "tag": 0,
                  "what": "class"
                },
                "range": {"line": 43, "column": 4, "end_line": 45, "end_column": 7}
              },
              {
                "index": 2,
                "item": "functor",
                "name": "Scale",
                "word": {
                  "kind": "pointer",
                  "tag": 247,
                  "what": "closure"
                },
                "range": {"line": 47, "column": 4, "end_line": 51, "end_column": 7}
              }
            ],
            "no_field": [],
            "range": {"line": 40, "column": 2, "end_line": 52, "end_column": 5}
          },
          {
            "name": "EMPTY",
            "line": 77,
            "size": 0,
            "fields": [],
            "no_field": [
              "type t"
            ],
            "range": {"line": 72, "column": 0, "end_line": 74, "end_column": 3}
          },
          {
            "name": "PARITY",
            "line": 89,
            "size": 2,
            "fields": [
              {
                "index": 0,
                "item": "value",
                "name": "even",
                "word": {
                  "kind": "pointer",
                  "tag": null,
                  "what": "closure, Closure_tag 247 or Infix_tag 249"
                },
                "range": {"line": 84, "column": 2, "end_line": 84, "end_column": 24}
              },
              {
                "index": 1,
                "item": "value",
                "name": "odd",
                "word": {
                  "kind": "pointer",
                  "tag": null,
                  "what": "closure, Closure_tag 247 or Infix_tag 249"
                },
                "range": {"line": 85, "column": 2, "end_line": 85, "end_column": 23}
              }
            ],
            "no_field": [],
            "range": {"line": 83, "column": 0, "end_line": 86, "end_column": 3}
          }
        ],
        "labels": [],
        "values": {
          "closures": [
            {
              "backend": "native code",
              "config": "Closure, without flambda",
              "closures": []
            }
          ],
          "lazy": [],
          "objects": [
            {
              "name": "class drawing",
              "line": 59,
              "env_slot": false,
              "vars": [],
              "unknown": [],
              "range": {"line": 59, "column": 4, "end_line": 62, "end_column": 9}
            }
          ]
        }
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
                  "value": 4100401,
                  "cost": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 1, "column": 16, "end_line": 1, "end_column": 20}
              },
              {
                "name": "`Blue",
                "shape": {
                  "kind": "immediate",
                  "value": 737308346,
                  "cost": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 1, "column": 32, "end_line": 1, "end_column": 37}
              },
              {
                "name": "`Green",
                "shape": {
                  "kind": "immediate",
                  "value": 756711075,
                  "cost": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 1, "column": 23, "end_line": 1, "end_column": 29}
              }
            ],
            "notes": [],
            "range": {"line": 1, "column": 0, "end_line": 1, "end_column": 39}
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
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": null
                    },
                    {
                      "kind": "arg",
                      "type": "int * int",
                      "mutable": false,
                      "word": {
                        "kind": "pointer",
                        "tag": 0,
                        "what": "tuple"
                      },
                      "owns": {
                        "words": [3],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": null
                    }
                  ],
                  "cost": {
                    "words": [6],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 2, "column": 30, "end_line": 2, "end_column": 49}
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
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": null
                    },
                    {
                      "kind": "arg",
                      "type": "char",
                      "mutable": false,
                      "word": {
                        "kind": "immediate",
                        "why": "char"
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": null
                    }
                  ],
                  "cost": {
                    "words": [3],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 2, "column": 15, "end_line": 2, "end_column": 27}
              },
              {
                "name": "`Quit",
                "shape": {
                  "kind": "immediate",
                  "value": 904096751,
                  "cost": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 2, "column": 52, "end_line": 2, "end_column": 57}
              }
            ],
            "notes": [],
            "range": {"line": 2, "column": 0, "end_line": 2, "end_column": 59}
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
                  "value": 65,
                  "cost": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": null
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
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": null
                    },
                    {
                      "kind": "arg",
                      "type": "int",
                      "mutable": false,
                      "word": {
                        "kind": "immediate",
                        "why": "int"
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": null
                    }
                  ],
                  "cost": {
                    "words": [3],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": null
              }
            ],
            "notes": [],
            "range": {"line": 3, "column": 0, "end_line": 3, "end_column": 55}
          },
          {
            "name": "nested",
            "params": "",
            "keyword": "type",
            "line": 4,
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
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  },
                  "range": {"line": 4, "column": 16, "end_line": 4, "end_column": 27}
                },
                {
                  "kind": "label",
                  "name": "e",
                  "type": "event",
                  "mutable": false,
                  "word": {
                    "kind": "any",
                    "why": "polymorphic variant"
                  },
                  "owns": {
                    "words": [0, 3, 6],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  },
                  "range": {"line": 4, "column": 28, "end_line": 4, "end_column": 37}
                }
              ],
              "cost": {
                "words": [3, 6, 9],
                "range": false,
                "not_counted": [],
                "nodes": false
              }
            },
            "notes": [],
            "range": {"line": 4, "column": 0, "end_line": 4, "end_column": 39}
          },
          {
            "name": "one",
            "params": "",
            "keyword": "type",
            "line": 7,
            "kind": "polymorphic_variant",
            "closed": true,
            "cases": [
              {
                "name": "`Eric_Cooper",
                "shape": {
                  "kind": "immediate",
                  "value": -332323982,
                  "cost": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 7, "column": 13, "end_line": 7, "end_column": 25}
              }
            ],
            "notes": [],
            "range": {"line": 7, "column": 0, "end_line": 7, "end_column": 27}
          },
          {
            "name": "other",
            "params": "",
            "keyword": "type",
            "line": 8,
            "kind": "polymorphic_variant",
            "closed": true,
            "cases": [
              {
                "name": "`azdwbie",
                "shape": {
                  "kind": "block",
                  "tag": 0,
                  "size": 2,
                  "fields": [
                    {
                      "kind": "hash",
                      "hash": -332323982,
                      "type": "int",
                      "mutable": false,
                      "word": {
                        "kind": "immediate",
                        "why": "label hash"
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": null
                    },
                    {
                      "kind": "arg",
                      "type": "int",
                      "mutable": false,
                      "word": {
                        "kind": "immediate",
                        "why": "int"
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": null
                    }
                  ],
                  "cost": {
                    "words": [3],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 8, "column": 15, "end_line": 8, "end_column": 30}
              }
            ],
            "notes": [],
            "range": {"line": 8, "column": 0, "end_line": 8, "end_column": 32}
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
            "label": "Eric_Cooper",
            "hash": -332323982,
            "file": "cases/polyvariants.ml",
            "line": 7
          },
          {
            "label": "azdwbie",
            "hash": -332323982,
            "file": "cases/polyvariants.ml",
            "line": 8
          },
          {
            "label": "Foo",
            "hash": 3505894,
            "file": "cases/polyvariants.ml",
            "line": 10
          },
          {
            "label": "Bar",
            "hash": 3303859,
            "file": "cases/polyvariants.ml",
            "line": 10
          }
        ],
        "values": {
          "closures": [
            {
              "backend": "native code",
              "config": "Closure, without flambda",
              "closures": []
            }
          ],
          "lazy": [],
          "objects": []
        }
      }
    ],
    "collisions": [
      {
        "hash": -332323982,
        "labels": [
          {
            "label": "Eric_Cooper",
            "hash": -332323982,
            "file": "cases/polyvariants.ml",
            "line": 7
          },
          {
            "label": "azdwbie",
            "hash": -332323982,
            "file": "cases/polyvariants.ml",
            "line": 8
          }
        ]
      }
    ]
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
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  },
                  "range": {"line": 1, "column": 11, "end_line": 1, "end_column": 19}
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
                  },
                  "owns": {
                    "words": [2],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  },
                  "range": {"line": 1, "column": 20, "end_line": 1, "end_column": 29}
                }
              ],
              "cost": {
                "words": [5],
                "range": false,
                "not_counted": [],
                "nodes": false
              }
            },
            "notes": [],
            "range": {"line": 1, "column": 0, "end_line": 1, "end_column": 31}
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
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  },
                  "range": {"line": 2, "column": 15, "end_line": 2, "end_column": 25}
                },
                {
                  "kind": "label",
                  "name": "y",
                  "type": "float",
                  "mutable": true,
                  "word": {
                    "kind": "double"
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  },
                  "range": {"line": 2, "column": 26, "end_line": 2, "end_column": 43}
                }
              ],
              "cost": {
                "words": [3],
                "range": false,
                "not_counted": [],
                "nodes": false
              }
            },
            "notes": [],
            "range": {"line": 2, "column": 0, "end_line": 2, "end_column": 45}
          },
          {
            "name": "fbox",
            "params": "",
            "keyword": "type",
            "line": 3,
            "kind": "record",
            "shape": {
              "kind": "unboxed",
              "field": {
                "kind": "label",
                "name": "f",
                "type": "float",
                "mutable": false,
                "word": {
                  "kind": "pointer",
                  "tag": 253,
                  "what": "boxed float"
                },
                "owns": {
                  "words": [2],
                  "range": false,
                  "not_counted": [],
                  "nodes": false
                },
                "range": {"line": 3, "column": 14, "end_line": 3, "end_column": 23}
              },
              "cost": {
                "words": [2],
                "range": false,
                "not_counted": [],
                "nodes": false
              }
            },
            "notes": [],
            "range": {"line": 3, "column": 0, "end_line": 3, "end_column": 37}
          },
          {
            "name": "id",
            "params": "",
            "keyword": "type",
            "line": 4,
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
                    },
                    "owns": {
                      "words": [0],
                      "range": false,
                      "not_counted": [],
                      "nodes": false
                    },
                    "range": {"line": 4, "column": 16, "end_line": 4, "end_column": 19}
                  },
                  "cost": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 4, "column": 10, "end_line": 4, "end_column": 19}
              }
            ],
            "notes": [],
            "range": {"line": 4, "column": 0, "end_line": 4, "end_column": 31}
          },
          {
            "name": "iu",
            "params": "",
            "keyword": "type",
            "line": 5,
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
                    },
                    "owns": {
                      "words": [0],
                      "range": false,
                      "not_counted": [],
                      "nodes": false
                    },
                    "range": {"line": 5, "column": 18, "end_line": 5, "end_column": 26}
                  },
                  "cost": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 5, "column": 10, "end_line": 5, "end_column": 28}
              }
            ],
            "notes": [],
            "range": {"line": 5, "column": 0, "end_line": 5, "end_column": 40}
          },
          {
            "name": "metres",
            "params": "",
            "keyword": "type",
            "line": 9,
            "kind": "alias",
            "word": {
              "kind": "pointer",
              "tag": 253,
              "what": "boxed float"
            },
            "notes": [],
            "range": {"line": 9, "column": 0, "end_line": 9, "end_column": 19}
          },
          {
            "name": "Opaque.t",
            "params": "",
            "keyword": "type",
            "line": 14,
            "kind": "alias",
            "word": {
              "kind": "pointer",
              "tag": 253,
              "what": "boxed float"
            },
            "notes": [],
            "range": {"line": 14, "column": 2, "end_line": 14, "end_column": 16}
          },
          {
            "name": "seen",
            "params": "",
            "keyword": "type",
            "line": 17,
            "kind": "record",
            "shape": {
              "kind": "block",
              "tag": 254,
              "size": 2,
              "flat_float": true,
              "fields": [
                {
                  "kind": "label",
                  "name": "m",
                  "type": "metres",
                  "mutable": false,
                  "word": {
                    "kind": "double"
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  },
                  "range": {"line": 17, "column": 14, "end_line": 17, "end_column": 25}
                },
                {
                  "kind": "label",
                  "name": "fb",
                  "type": "fbox",
                  "mutable": false,
                  "word": {
                    "kind": "double"
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  },
                  "range": {"line": 17, "column": 26, "end_line": 17, "end_column": 35}
                }
              ],
              "cost": {
                "words": [3],
                "range": false,
                "not_counted": [],
                "nodes": false
              }
            },
            "notes": [],
            "range": {"line": 17, "column": 0, "end_line": 17, "end_column": 37}
          },
          {
            "name": "hidden",
            "params": "",
            "keyword": "type",
            "line": 18,
            "kind": "record",
            "shape": {
              "kind": "block",
              "tag": 0,
              "size": 2,
              "fields": [
                {
                  "kind": "label",
                  "name": "o",
                  "type": "Opaque.t",
                  "mutable": false,
                  "word": {
                    "kind": "any",
                    "why": "abstract type Opaque.t"
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [
                      {
                        "what": "abstract type Opaque.t",
                        "per_node": null
                      }
                    ],
                    "nodes": false
                  },
                  "range": {"line": 18, "column": 16, "end_line": 18, "end_column": 29}
                },
                {
                  "kind": "label",
                  "name": "h",
                  "type": "float",
                  "mutable": false,
                  "word": {
                    "kind": "pointer",
                    "tag": 253,
                    "what": "boxed float"
                  },
                  "owns": {
                    "words": [2],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  },
                  "range": {"line": 18, "column": 30, "end_line": 18, "end_column": 39}
                }
              ],
              "cost": {
                "words": [5],
                "range": false,
                "not_counted": [
                  {
                    "what": "abstract type Opaque.t",
                    "per_node": null
                  }
                ],
                "nodes": false
              }
            },
            "notes": [],
            "range": {"line": 18, "column": 0, "end_line": 18, "end_column": 41}
          },
          {
            "name": "inline",
            "params": "",
            "keyword": "type",
            "line": 20,
            "kind": "variant",
            "cases": [
              {
                "name": "I0",
                "shape": {
                  "kind": "immediate",
                  "value": 0,
                  "cost": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 21, "column": 2, "end_line": 21, "end_column": 6}
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
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": {"line": 22, "column": 10, "end_line": 22, "end_column": 13}
                    }
                  ],
                  "cost": {
                    "words": [2],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 22, "column": 2, "end_line": 22, "end_column": 13}
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
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": {"line": 23, "column": 12, "end_line": 23, "end_column": 21}
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
                      },
                      "owns": {
                        "words": [2],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": {"line": 23, "column": 22, "end_line": 23, "end_column": 32}
                    }
                  ],
                  "cost": {
                    "words": [5],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 23, "column": 2, "end_line": 23, "end_column": 34}
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
                      },
                      "owns": {
                        "words": [2],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": {"line": 24, "column": 12, "end_line": 24, "end_column": 23}
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
                      },
                      "owns": {
                        "words": [2],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": {"line": 24, "column": 24, "end_line": 24, "end_column": 34}
                    }
                  ],
                  "cost": {
                    "words": [7],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [
                  "inline record: all fields are float, but inline records are never stored flat"
                ],
                "range": {"line": 24, "column": 2, "end_line": 24, "end_column": 36}
              }
            ],
            "notes": [],
            "range": {"line": 20, "column": 0, "end_line": 24, "end_column": 36}
          },
          {
            "name": "uses",
            "params": "",
            "keyword": "type",
            "line": 26,
            "kind": "record",
            "shape": {
              "kind": "block",
              "tag": 0,
              "size": 9,
              "fields": [
                {
                  "kind": "label",
                  "name": "t",
                  "type": "inline",
                  "mutable": false,
                  "word": {
                    "kind": "any",
                    "why": "inline"
                  },
                  "owns": {
                    "words": [0, 2, 5, 7],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  },
                  "range": {"line": 27, "column": 2, "end_line": 27, "end_column": 13}
                },
                {
                  "kind": "label",
                  "name": "ids",
                  "type": "id list",
                  "mutable": false,
                  "word": {
                    "kind": "any",
                    "why": "list"
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [
                      {
                        "what": "id list",
                        "per_node": {
                          "words": [3],
                          "range": false,
                          "not_counted": [],
                          "nodes": true
                        }
                      }
                    ],
                    "nodes": false
                  },
                  "range": {"line": 28, "column": 2, "end_line": 28, "end_column": 16}
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
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [
                      {
                        "what": "array",
                        "per_node": null
                      }
                    ],
                    "nodes": false
                  },
                  "range": {"line": 29, "column": 2, "end_line": 29, "end_column": 20}
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
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [
                      {
                        "what": "array",
                        "per_node": null
                      }
                    ],
                    "nodes": false
                  },
                  "range": {"line": 30, "column": 2, "end_line": 30, "end_column": 19}
                },
                {
                  "kind": "label",
                  "name": "opt",
                  "type": "int option",
                  "mutable": false,
                  "word": {
                    "kind": "any",
                    "why": "option"
                  },
                  "owns": {
                    "words": [0, 2],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  },
                  "range": {"line": 31, "column": 2, "end_line": 31, "end_column": 19}
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
                  },
                  "owns": {
                    "words": [3],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  },
                  "range": {"line": 32, "column": 2, "end_line": 32, "end_column": 14}
                },
                {
                  "kind": "label",
                  "name": "ch",
                  "type": "char",
                  "mutable": false,
                  "word": {
                    "kind": "immediate",
                    "why": "char"
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  },
                  "range": {"line": 33, "column": 2, "end_line": 33, "end_column": 12}
                },
                {
                  "kind": "label",
                  "name": "lz",
                  "type": "int Lazy.t",
                  "mutable": false,
                  "word": {
                    "kind": "any",
                    "why": "lazy value"
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [
                      {
                        "what": "lazy value",
                        "per_node": null
                      }
                    ],
                    "nodes": false
                  },
                  "range": {"line": 34, "column": 2, "end_line": 34, "end_column": 18}
                },
                {
                  "kind": "label",
                  "name": "apply",
                  "type": "'a. 'a -> 'a",
                  "mutable": false,
                  "word": {
                    "kind": "pointer",
                    "tag": null,
                    "what": "closure, Closure_tag 247 or Infix_tag 249"
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [
                      {
                        "what": "closure",
                        "per_node": null
                      }
                    ],
                    "nodes": false
                  },
                  "range": {"line": 35, "column": 2, "end_line": 35, "end_column": 23}
                }
              ],
              "cost": {
                "words": [13, 15, 17, 18, 20, 22],
                "range": false,
                "not_counted": [
                  {
                    "what": "id list",
                    "per_node": {
                      "words": [3],
                      "range": false,
                      "not_counted": [],
                      "nodes": true
                    }
                  },
                  {
                    "what": "array",
                    "per_node": null
                  },
                  {
                    "what": "array",
                    "per_node": null
                  },
                  {
                    "what": "lazy value",
                    "per_node": null
                  },
                  {
                    "what": "closure",
                    "per_node": null
                  }
                ],
                "nodes": false
              }
            },
            "notes": [],
            "range": {"line": 26, "column": 0, "end_line": 36, "end_column": 1}
          }
        ],
        "packages": [],
        "labels": [],
        "values": {
          "closures": [
            {
              "backend": "native code",
              "config": "Closure, without flambda",
              "closures": []
            }
          ],
          "lazy": [],
          "objects": []
        }
      }
    ],
    "collisions": []
  }
  ### cases/recursive.ml
  {
    "word_size": 64,
    "units": [
      {
        "file": "cases/recursive.ml",
        "unit": "Recursive",
        "types": [
          {
            "name": "node",
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
                  "name": "v",
                  "type": "int",
                  "mutable": false,
                  "word": {
                    "kind": "immediate",
                    "why": "int"
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  },
                  "range": {"line": 1, "column": 14, "end_line": 1, "end_column": 22}
                },
                {
                  "kind": "label",
                  "name": "next",
                  "type": "node option",
                  "mutable": true,
                  "word": {
                    "kind": "any",
                    "why": "option"
                  },
                  "owns": {
                    "words": [0, 2],
                    "range": false,
                    "not_counted": [],
                    "nodes": true
                  },
                  "range": {"line": 1, "column": 23, "end_line": 1, "end_column": 49}
                }
              ],
              "cost": {
                "words": [3, 5],
                "range": false,
                "not_counted": [],
                "nodes": true
              }
            },
            "notes": [],
            "range": {"line": 1, "column": 0, "end_line": 1, "end_column": 51}
          },
          {
            "name": "cell",
            "params": "",
            "keyword": "type",
            "line": 2,
            "kind": "variant",
            "cases": [
              {
                "name": "Nil",
                "shape": {
                  "kind": "immediate",
                  "value": 0,
                  "cost": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 2, "column": 12, "end_line": 2, "end_column": 15}
              },
              {
                "name": "Cons",
                "shape": {
                  "kind": "block",
                  "tag": 0,
                  "size": 2,
                  "fields": [
                    {
                      "kind": "label",
                      "name": "v",
                      "type": "int",
                      "mutable": false,
                      "word": {
                        "kind": "immediate",
                        "why": "int"
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": {"line": 2, "column": 28, "end_line": 2, "end_column": 36}
                    },
                    {
                      "kind": "label",
                      "name": "next",
                      "type": "cell",
                      "mutable": true,
                      "word": {
                        "kind": "any",
                        "why": "cell"
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [],
                        "nodes": true
                      },
                      "range": {"line": 2, "column": 37, "end_line": 2, "end_column": 56}
                    }
                  ],
                  "cost": {
                    "words": [3],
                    "range": false,
                    "not_counted": [],
                    "nodes": true
                  }
                },
                "notes": [],
                "range": {"line": 2, "column": 16, "end_line": 2, "end_column": 58}
              }
            ],
            "notes": [],
            "range": {"line": 2, "column": 0, "end_line": 2, "end_column": 58}
          },
          {
            "name": "expr",
            "params": "",
            "keyword": "type",
            "line": 3,
            "kind": "variant",
            "cases": [
              {
                "name": "Num",
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
                      },
                      "owns": {
                        "words": [2],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": {"line": 3, "column": 19, "end_line": 3, "end_column": 24}
                    }
                  ],
                  "cost": {
                    "words": [4],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 3, "column": 12, "end_line": 3, "end_column": 24}
              },
              {
                "name": "Add",
                "shape": {
                  "kind": "block",
                  "tag": 1,
                  "size": 2,
                  "fields": [
                    {
                      "kind": "arg",
                      "type": "expr",
                      "mutable": false,
                      "word": {
                        "kind": "pointer",
                        "tag": null,
                        "what": "expr"
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [],
                        "nodes": true
                      },
                      "range": {"line": 3, "column": 34, "end_line": 3, "end_column": 38}
                    },
                    {
                      "kind": "arg",
                      "type": "expr",
                      "mutable": false,
                      "word": {
                        "kind": "pointer",
                        "tag": null,
                        "what": "expr"
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [],
                        "nodes": true
                      },
                      "range": {"line": 3, "column": 41, "end_line": 3, "end_column": 45}
                    }
                  ],
                  "cost": {
                    "words": [3],
                    "range": false,
                    "not_counted": [],
                    "nodes": true
                  }
                },
                "notes": [],
                "range": {"line": 3, "column": 25, "end_line": 3, "end_column": 45}
              },
              {
                "name": "Neg",
                "shape": {
                  "kind": "block",
                  "tag": 2,
                  "size": 1,
                  "fields": [
                    {
                      "kind": "arg",
                      "type": "expr",
                      "mutable": false,
                      "word": {
                        "kind": "pointer",
                        "tag": null,
                        "what": "expr"
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [],
                        "nodes": true
                      },
                      "range": {"line": 3, "column": 55, "end_line": 3, "end_column": 59}
                    }
                  ],
                  "cost": {
                    "words": [2],
                    "range": false,
                    "not_counted": [],
                    "nodes": true
                  }
                },
                "notes": [],
                "range": {"line": 3, "column": 46, "end_line": 3, "end_column": 59}
              }
            ],
            "notes": [],
            "range": {"line": 3, "column": 0, "end_line": 3, "end_column": 59}
          },
          {
            "name": "forest",
            "params": "",
            "keyword": "type",
            "line": 4,
            "kind": "variant",
            "cases": [
              {
                "name": "Tree",
                "shape": {
                  "kind": "block",
                  "tag": 0,
                  "size": 2,
                  "fields": [
                    {
                      "kind": "arg",
                      "type": "int",
                      "mutable": false,
                      "word": {
                        "kind": "immediate",
                        "why": "int"
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": {"line": 4, "column": 22, "end_line": 4, "end_column": 25}
                    },
                    {
                      "kind": "arg",
                      "type": "forest list",
                      "mutable": false,
                      "word": {
                        "kind": "any",
                        "why": "list"
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [
                          {
                            "what": "forest list",
                            "per_node": {
                              "words": [3],
                              "range": false,
                              "not_counted": [],
                              "nodes": true
                            }
                          }
                        ],
                        "nodes": true
                      },
                      "range": {"line": 4, "column": 28, "end_line": 4, "end_column": 39}
                    }
                  ],
                  "cost": {
                    "words": [3],
                    "range": false,
                    "not_counted": [
                      {
                        "what": "forest list",
                        "per_node": {
                          "words": [3],
                          "range": false,
                          "not_counted": [],
                          "nodes": true
                        }
                      }
                    ],
                    "nodes": true
                  }
                },
                "notes": [],
                "range": {"line": 4, "column": 14, "end_line": 4, "end_column": 39}
              }
            ],
            "notes": [],
            "range": {"line": 4, "column": 0, "end_line": 4, "end_column": 39}
          },
          {
            "name": "even",
            "params": "",
            "keyword": "type",
            "line": 6,
            "kind": "variant",
            "cases": [
              {
                "name": "Zero",
                "shape": {
                  "kind": "immediate",
                  "value": 0,
                  "cost": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 6, "column": 12, "end_line": 6, "end_column": 16}
              },
              {
                "name": "Succ",
                "shape": {
                  "kind": "block",
                  "tag": 0,
                  "size": 1,
                  "fields": [
                    {
                      "kind": "arg",
                      "type": "odd",
                      "mutable": false,
                      "word": {
                        "kind": "pointer",
                        "tag": 0,
                        "what": "record odd"
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [],
                        "nodes": true
                      },
                      "range": {"line": 6, "column": 27, "end_line": 6, "end_column": 30}
                    }
                  ],
                  "cost": {
                    "words": [2],
                    "range": false,
                    "not_counted": [],
                    "nodes": true
                  }
                },
                "notes": [],
                "range": {"line": 6, "column": 17, "end_line": 6, "end_column": 30}
              }
            ],
            "notes": [],
            "range": {"line": 6, "column": 0, "end_line": 6, "end_column": 30}
          },
          {
            "name": "odd",
            "params": "",
            "keyword": "type",
            "line": 7,
            "kind": "record",
            "shape": {
              "kind": "block",
              "tag": 0,
              "size": 1,
              "fields": [
                {
                  "kind": "label",
                  "name": "pred",
                  "type": "even",
                  "mutable": false,
                  "word": {
                    "kind": "any",
                    "why": "even"
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": true
                  },
                  "range": {"line": 7, "column": 12, "end_line": 7, "end_column": 23}
                }
              ],
              "cost": {
                "words": [2],
                "range": false,
                "not_counted": [],
                "nodes": true
              }
            },
            "notes": [],
            "range": {"line": 7, "column": 0, "end_line": 7, "end_column": 25}
          },
          {
            "name": "seq",
            "params": "'a",
            "keyword": "type",
            "line": 9,
            "kind": "variant",
            "cases": [
              {
                "name": "Seq",
                "shape": {
                  "kind": "unboxed",
                  "field": {
                    "kind": "arg",
                    "type": "('a * 'a seq) option",
                    "mutable": false,
                    "word": {
                      "kind": "any",
                      "why": "option"
                    },
                    "owns": {
                      "words": [0, 5],
                      "range": false,
                      "not_counted": [
                        {
                          "what": "'a",
                          "per_node": null
                        }
                      ],
                      "nodes": true
                    },
                    "range": {"line": 9, "column": 21, "end_line": 9, "end_column": 41}
                  },
                  "cost": {
                    "words": [0, 5],
                    "range": false,
                    "not_counted": [
                      {
                        "what": "'a",
                        "per_node": null
                      }
                    ],
                    "nodes": true
                  }
                },
                "notes": [],
                "range": {"line": 9, "column": 14, "end_line": 9, "end_column": 41}
              }
            ],
            "notes": [],
            "range": {"line": 9, "column": 0, "end_line": 9, "end_column": 53}
          },
          {
            "name": "json",
            "params": "",
            "keyword": "type",
            "line": 10,
            "kind": "polymorphic_variant",
            "closed": true,
            "cases": [
              {
                "name": "`Num",
                "shape": {
                  "kind": "block",
                  "tag": 0,
                  "size": 2,
                  "fields": [
                    {
                      "kind": "hash",
                      "hash": 3905062,
                      "type": "int",
                      "mutable": false,
                      "word": {
                        "kind": "immediate",
                        "why": "label hash"
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": null
                    },
                    {
                      "kind": "arg",
                      "type": "float",
                      "mutable": false,
                      "word": {
                        "kind": "pointer",
                        "tag": 253,
                        "what": "boxed float"
                      },
                      "owns": {
                        "words": [2],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": null
                    }
                  ],
                  "cost": {
                    "words": [5],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 10, "column": 22, "end_line": 10, "end_column": 35}
              },
              {
                "name": "`List",
                "shape": {
                  "kind": "block",
                  "tag": 0,
                  "size": 2,
                  "fields": [
                    {
                      "kind": "hash",
                      "hash": 848054398,
                      "type": "int",
                      "mutable": false,
                      "word": {
                        "kind": "immediate",
                        "why": "label hash"
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": null
                    },
                    {
                      "kind": "arg",
                      "type": "json list",
                      "mutable": false,
                      "word": {
                        "kind": "any",
                        "why": "list"
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [
                          {
                            "what": "json list",
                            "per_node": {
                              "words": [3],
                              "range": false,
                              "not_counted": [],
                              "nodes": true
                            }
                          }
                        ],
                        "nodes": true
                      },
                      "range": null
                    }
                  ],
                  "cost": {
                    "words": [3],
                    "range": false,
                    "not_counted": [
                      {
                        "what": "json list",
                        "per_node": {
                          "words": [3],
                          "range": false,
                          "not_counted": [],
                          "nodes": true
                        }
                      }
                    ],
                    "nodes": true
                  }
                },
                "notes": [],
                "range": {"line": 10, "column": 38, "end_line": 10, "end_column": 56}
              },
              {
                "name": "`Null",
                "shape": {
                  "kind": "immediate",
                  "value": 870828711,
                  "cost": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 10, "column": 14, "end_line": 10, "end_column": 19}
              }
            ],
            "notes": [],
            "range": {"line": 10, "column": 0, "end_line": 10, "end_column": 58}
          },
          {
            "name": "owned",
            "params": "",
            "keyword": "type",
            "line": 12,
            "kind": "record",
            "shape": {
              "kind": "block",
              "tag": 0,
              "size": 4,
              "fields": [
                {
                  "kind": "label",
                  "name": "xs",
                  "type": "float list",
                  "mutable": false,
                  "word": {
                    "kind": "any",
                    "why": "list"
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [
                      {
                        "what": "float list",
                        "per_node": {
                          "words": [5],
                          "range": false,
                          "not_counted": [],
                          "nodes": true
                        }
                      }
                    ],
                    "nodes": false
                  },
                  "range": {"line": 13, "column": 2, "end_line": 13, "end_column": 18}
                },
                {
                  "kind": "label",
                  "name": "pt",
                  "type": "(float * float) option",
                  "mutable": false,
                  "word": {
                    "kind": "any",
                    "why": "option"
                  },
                  "owns": {
                    "words": [0, 9],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  },
                  "range": {"line": 14, "column": 2, "end_line": 14, "end_column": 30}
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
                  },
                  "owns": {
                    "words": [3],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  },
                  "range": {"line": 15, "column": 2, "end_line": 15, "end_column": 14}
                },
                {
                  "kind": "label",
                  "name": "name",
                  "type": "string",
                  "mutable": false,
                  "word": {
                    "kind": "pointer",
                    "tag": 252,
                    "what": "string"
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [
                      {
                        "what": "string",
                        "per_node": null
                      }
                    ],
                    "nodes": false
                  },
                  "range": {"line": 16, "column": 2, "end_line": 16, "end_column": 16}
                }
              ],
              "cost": {
                "words": [8, 17],
                "range": false,
                "not_counted": [
                  {
                    "what": "float list",
                    "per_node": {
                      "words": [5],
                      "range": false,
                      "not_counted": [],
                      "nodes": true
                    }
                  },
                  {
                    "what": "string",
                    "per_node": null
                  }
                ],
                "nodes": false
              }
            },
            "notes": [],
            "range": {"line": 12, "column": 0, "end_line": 17, "end_column": 1}
          }
        ],
        "packages": [],
        "labels": [
          {
            "label": "Null",
            "hash": 870828711,
            "file": "cases/recursive.ml",
            "line": 10
          },
          {
            "label": "Num",
            "hash": 3905062,
            "file": "cases/recursive.ml",
            "line": 10
          },
          {
            "label": "List",
            "hash": 848054398,
            "file": "cases/recursive.ml",
            "line": 10
          }
        ],
        "values": {
          "closures": [
            {
              "backend": "native code",
              "config": "Closure, without flambda",
              "closures": []
            }
          ],
          "lazy": [],
          "objects": []
        }
      }
    ],
    "collisions": []
  }
  ### cases/sample.ml
  {
    "word_size": 64,
    "units": [
      {
        "file": "cases/sample.ml",
        "unit": "Sample",
        "types": [
          {
            "name": "shape",
            "params": "",
            "keyword": "type",
            "line": 2,
            "kind": "variant",
            "cases": [
              {
                "name": "Point",
                "shape": {
                  "kind": "immediate",
                  "value": 0,
                  "cost": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 2, "column": 13, "end_line": 2, "end_column": 18}
              },
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
                      },
                      "owns": {
                        "words": [2],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": {"line": 2, "column": 31, "end_line": 2, "end_column": 36}
                    }
                  ],
                  "cost": {
                    "words": [4],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 2, "column": 19, "end_line": 2, "end_column": 36}
              },
              {
                "name": "Rect",
                "shape": {
                  "kind": "block",
                  "tag": 1,
                  "size": 2,
                  "fields": [
                    {
                      "kind": "label",
                      "name": "w",
                      "type": "float",
                      "mutable": false,
                      "word": {
                        "kind": "pointer",
                        "tag": 253,
                        "what": "boxed float"
                      },
                      "owns": {
                        "words": [2],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": {"line": 2, "column": 49, "end_line": 2, "end_column": 59}
                    },
                    {
                      "kind": "label",
                      "name": "h",
                      "type": "float",
                      "mutable": false,
                      "word": {
                        "kind": "pointer",
                        "tag": 253,
                        "what": "boxed float"
                      },
                      "owns": {
                        "words": [2],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": {"line": 2, "column": 60, "end_line": 2, "end_column": 69}
                    }
                  ],
                  "cost": {
                    "words": [7],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [
                  "inline record: all fields are float, but inline records are never stored flat"
                ],
                "range": {"line": 2, "column": 37, "end_line": 2, "end_column": 71}
              }
            ],
            "notes": [],
            "range": {"line": 2, "column": 0, "end_line": 2, "end_column": 71}
          },
          {
            "name": "colour",
            "params": "",
            "keyword": "type",
            "line": 3,
            "kind": "variant",
            "cases": [
              {
                "name": "Red",
                "shape": {
                  "kind": "immediate",
                  "value": 0,
                  "cost": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 3, "column": 14, "end_line": 3, "end_column": 17}
              },
              {
                "name": "Green",
                "shape": {
                  "kind": "immediate",
                  "value": 1,
                  "cost": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 3, "column": 18, "end_line": 3, "end_column": 25}
              },
              {
                "name": "Blue",
                "shape": {
                  "kind": "immediate",
                  "value": 2,
                  "cost": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 3, "column": 26, "end_line": 3, "end_column": 32}
              }
            ],
            "notes": [],
            "range": {"line": 3, "column": 0, "end_line": 3, "end_column": 32}
          },
          {
            "name": "vec",
            "params": "",
            "keyword": "type",
            "line": 4,
            "kind": "record",
            "shape": {
              "kind": "block",
              "tag": 254,
              "size": 3,
              "flat_float": true,
              "fields": [
                {
                  "kind": "label",
                  "name": "x",
                  "type": "float",
                  "mutable": false,
                  "word": {
                    "kind": "double"
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  },
                  "range": {"line": 4, "column": 13, "end_line": 4, "end_column": 23}
                },
                {
                  "kind": "label",
                  "name": "y",
                  "type": "float",
                  "mutable": false,
                  "word": {
                    "kind": "double"
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  },
                  "range": {"line": 4, "column": 24, "end_line": 4, "end_column": 34}
                },
                {
                  "kind": "label",
                  "name": "z",
                  "type": "float",
                  "mutable": false,
                  "word": {
                    "kind": "double"
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  },
                  "range": {"line": 4, "column": 35, "end_line": 4, "end_column": 44}
                }
              ],
              "cost": {
                "words": [4],
                "range": false,
                "not_counted": [],
                "nodes": false
              }
            },
            "notes": [],
            "range": {"line": 4, "column": 0, "end_line": 4, "end_column": 46}
          },
          {
            "name": "id",
            "params": "",
            "keyword": "type",
            "line": 5,
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
                    },
                    "owns": {
                      "words": [0],
                      "range": false,
                      "not_counted": [],
                      "nodes": false
                    },
                    "range": {"line": 5, "column": 16, "end_line": 5, "end_column": 19}
                  },
                  "cost": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 5, "column": 10, "end_line": 5, "end_column": 19}
              }
            ],
            "notes": [],
            "range": {"line": 5, "column": 0, "end_line": 5, "end_column": 31}
          }
        ],
        "packages": [],
        "labels": [],
        "values": {
          "closures": [
            {
              "backend": "native code",
              "config": "Closure, without flambda",
              "closures": []
            }
          ],
          "lazy": [],
          "objects": []
        }
      }
    ],
    "collisions": []
  }
  ### cases/values.ml
  {
    "word_size": 64,
    "units": [
      {
        "file": "cases/values.ml",
        "unit": "Values",
        "types": [
          {
            "name": "counter",
            "params": "",
            "keyword": "type",
            "line": 31,
            "kind": "record",
            "shape": {
              "kind": "block",
              "tag": 0,
              "size": 2,
              "fields": [
                {
                  "kind": "label",
                  "name": "next",
                  "type": "unit -> int",
                  "mutable": false,
                  "word": {
                    "kind": "pointer",
                    "tag": null,
                    "what": "closure, Closure_tag 247 or Infix_tag 249"
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [
                      {
                        "what": "closure",
                        "per_node": null
                      }
                    ],
                    "nodes": false
                  },
                  "range": {"line": 31, "column": 17, "end_line": 31, "end_column": 36}
                },
                {
                  "kind": "label",
                  "name": "reset",
                  "type": "unit -> unit",
                  "mutable": false,
                  "word": {
                    "kind": "pointer",
                    "tag": null,
                    "what": "closure, Closure_tag 247 or Infix_tag 249"
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [
                      {
                        "what": "closure",
                        "per_node": null
                      }
                    ],
                    "nodes": false
                  },
                  "range": {"line": 31, "column": 37, "end_line": 31, "end_column": 57}
                }
              ],
              "cost": {
                "words": [3],
                "range": false,
                "not_counted": [
                  {
                    "what": "closure",
                    "per_node": null
                  },
                  {
                    "what": "closure",
                    "per_node": null
                  }
                ],
                "nodes": false
              }
            },
            "notes": [],
            "range": {"line": 31, "column": 0, "end_line": 31, "end_column": 59}
          }
        ],
        "packages": [],
        "labels": [],
        "values": {
          "closures": [
            {
              "backend": "native code",
              "config": "Closure, without flambda",
              "closures": [
                {
                  "size": 3,
                  "env_start": 2,
                  "functions": [
                    {
                      "name": "arities.inc",
                      "line": 8,
                      "arity": 1,
                      "tupled": false,
                      "offset": 0,
                      "code_words": 2,
                      "range": {"line": 8, "column": 2, "end_line": 8, "end_column": 19}
                    }
                  ],
                  "env": [
                    {
                      "name": "k",
                      "type": "int",
                      "word": {
                        "kind": "immediate",
                        "why": "int"
                      },
                      "bound_at": {"line": 7, "column": 12, "end_line": 7, "end_column": 13}
                    }
                  ]
                },
                {
                  "size": 4,
                  "env_start": 3,
                  "functions": [
                    {
                      "name": "arities.add",
                      "line": 9,
                      "arity": 2,
                      "tupled": false,
                      "offset": 0,
                      "code_words": 3,
                      "range": {"line": 9, "column": 2, "end_line": 9, "end_column": 25}
                    }
                  ],
                  "env": [
                    {
                      "name": "k",
                      "type": "int",
                      "word": {
                        "kind": "immediate",
                        "why": "int"
                      },
                      "bound_at": {"line": 7, "column": 12, "end_line": 7, "end_column": 13}
                    }
                  ]
                },
                {
                  "size": 4,
                  "env_start": 3,
                  "functions": [
                    {
                      "name": "arities.add_pair",
                      "line": 10,
                      "arity": 2,
                      "tupled": true,
                      "offset": 0,
                      "code_words": 3,
                      "range": {"line": 10, "column": 2, "end_line": 10, "end_column": 33}
                    }
                  ],
                  "env": [
                    {
                      "name": "k",
                      "type": "int",
                      "word": {
                        "kind": "immediate",
                        "why": "int"
                      },
                      "bound_at": {"line": 7, "column": 12, "end_line": 7, "end_column": 13}
                    }
                  ]
                },
                {
                  "size": 4,
                  "env_start": 2,
                  "functions": [
                    {
                      "name": "adder.(fun)",
                      "line": 13,
                      "arity": 1,
                      "tupled": false,
                      "offset": 0,
                      "code_words": 2,
                      "range": {"line": 13, "column": 16, "end_line": 13, "end_column": 34}
                    }
                  ],
                  "env": [
                    {
                      "name": "a",
                      "type": "int",
                      "word": {
                        "kind": "immediate",
                        "why": "int"
                      },
                      "bound_at": {"line": 13, "column": 10, "end_line": 13, "end_column": 11}
                    },
                    {
                      "name": "b",
                      "type": "int",
                      "word": {
                        "kind": "immediate",
                        "why": "int"
                      },
                      "bound_at": {"line": 13, "column": 12, "end_line": 13, "end_column": 13}
                    }
                  ]
                },
                {
                  "size": 3,
                  "env_start": 2,
                  "functions": [
                    {
                      "name": "scaler.(fun)",
                      "line": 14,
                      "arity": 1,
                      "tupled": false,
                      "offset": 0,
                      "code_words": 2,
                      "range": {"line": 14, "column": 15, "end_line": 14, "end_column": 37}
                    }
                  ],
                  "env": [
                    {
                      "name": "a",
                      "type": "int",
                      "word": {
                        "kind": "immediate",
                        "why": "int"
                      },
                      "bound_at": {"line": 14, "column": 11, "end_line": 14, "end_column": 12}
                    }
                  ]
                },
                {
                  "size": 6,
                  "env_start": 5,
                  "functions": [
                    {
                      "name": "parity.even",
                      "line": 17,
                      "arity": 1,
                      "tupled": false,
                      "offset": 0,
                      "code_words": 2,
                      "range": {"line": 17, "column": 2, "end_line": 17, "end_column": 39}
                    },
                    {
                      "name": "parity.odd",
                      "line": 17,
                      "arity": 1,
                      "tupled": false,
                      "offset": 3,
                      "code_words": 2,
                      "range": {"line": 17, "column": 40, "end_line": 17, "end_column": 74}
                    }
                  ],
                  "env": [
                    {
                      "name": "n",
                      "type": "int",
                      "word": {
                        "kind": "immediate",
                        "why": "int"
                      },
                      "bound_at": {"line": 16, "column": 11, "end_line": 16, "end_column": 12}
                    }
                  ]
                },
                {
                  "size": 8,
                  "env_start": 7,
                  "functions": [
                    {
                      "name": "bumper.bump",
                      "line": 21,
                      "arity": 2,
                      "tupled": false,
                      "offset": 0,
                      "code_words": 3,
                      "range": {"line": 21, "column": 2, "end_line": 21, "end_column": 35}
                    },
                    {
                      "name": "bumper.bump_inner",
                      "line": 21,
                      "arity": 2,
                      "tupled": false,
                      "offset": 4,
                      "code_words": 3,
                      "range": {"line": 21, "column": 2, "end_line": 21, "end_column": 35}
                    }
                  ],
                  "env": [
                    {
                      "name": "k",
                      "type": "int",
                      "word": {
                        "kind": "immediate",
                        "why": "int"
                      },
                      "bound_at": {"line": 20, "column": 11, "end_line": 20, "end_column": 12}
                    }
                  ]
                },
                {
                  "size": 3,
                  "env_start": 2,
                  "functions": [
                    {
                      "name": "counter.(fun)",
                      "line": 37,
                      "arity": 1,
                      "tupled": false,
                      "offset": 0,
                      "code_words": 2,
                      "range": {"line": 37, "column": 6, "end_line": 39, "end_column": 11}
                    }
                  ],
                  "env": [
                    {
                      "name": "n",
                      "type": "int ref",
                      "word": {
                        "kind": "pointer",
                        "tag": 0,
                        "what": "record Stdlib.ref"
                      },
                      "bound_at": {"line": 34, "column": 6, "end_line": 34, "end_column": 7}
                    }
                  ]
                },
                {
                  "size": 4,
                  "env_start": 2,
                  "functions": [
                    {
                      "name": "counter.(fun)",
                      "line": 40,
                      "arity": 1,
                      "tupled": false,
                      "offset": 0,
                      "code_words": 2,
                      "range": {"line": 40, "column": 12, "end_line": 40, "end_column": 34}
                    }
                  ],
                  "env": [
                    {
                      "name": "start",
                      "type": "int",
                      "word": {
                        "kind": "immediate",
                        "why": "int"
                      },
                      "bound_at": {"line": 33, "column": 12, "end_line": 33, "end_column": 17}
                    },
                    {
                      "name": "n",
                      "type": "int ref",
                      "word": {
                        "kind": "pointer",
                        "tag": 0,
                        "what": "record Stdlib.ref"
                      },
                      "bound_at": {"line": 34, "column": 6, "end_line": 34, "end_column": 7}
                    }
                  ]
                },
                {
                  "size": 3,
                  "env_start": 2,
                  "functions": [
                    {
                      "name": "lazies",
                      "line": 44,
                      "arity": 1,
                      "tupled": false,
                      "offset": 0,
                      "code_words": 2,
                      "range": {"line": 44, "column": 42, "end_line": 44, "end_column": 49}
                    }
                  ],
                  "env": [
                    {
                      "name": "i",
                      "type": "int",
                      "word": {
                        "kind": "immediate",
                        "why": "int"
                      },
                      "bound_at": {"line": 43, "column": 11, "end_line": 43, "end_column": 12}
                    }
                  ]
                }
              ]
            }
          ],
          "lazy": [
            {
              "line": 44,
              "source": "lazy 3",
              "kind": "itself",
              "word": {
                "kind": "immediate",
                "why": "int"
              },
              "range": {"line": 44, "column": 3, "end_line": 44, "end_column": 9}
            },
            {
              "line": 44,
              "source": "lazy 2.5",
              "kind": "forward",
              "word": {
                "kind": "pointer",
                "tag": 253,
                "what": "boxed float"
              },
              "range": {"line": 44, "column": 11, "end_line": 44, "end_column": 19}
            },
            {
              "line": 44,
              "source": "lazy i",
              "kind": "itself",
              "word": {
                "kind": "immediate",
                "why": "int"
              },
              "range": {"line": 44, "column": 21, "end_line": 44, "end_column": 27}
            },
            {
              "line": 44,
              "source": "lazy v",
              "kind": "forward",
              "word": {
                "kind": "any",
                "why": "type variable"
              },
              "range": {"line": 44, "column": 29, "end_line": 44, "end_column": 35}
            },
            {
              "line": 44,
              "source": "lazy (i + 1)",
              "kind": "lazy",
              "word": {
                "kind": "immediate",
                "why": "int"
              },
              "range": {"line": 44, "column": 37, "end_line": 44, "end_column": 49}
            },
            {
              "line": 44,
              "source": "lazy (fun x -> x)",
              "kind": "itself",
              "word": {
                "kind": "pointer",
                "tag": null,
                "what": "closure, Closure_tag 247 or Infix_tag 249"
              },
              "range": {"line": 44, "column": 51, "end_line": 44, "end_column": 68}
            }
          ],
          "objects": [
            {
              "name": "class point",
              "line": 46,
              "env_slot": false,
              "vars": [
                {
                  "name": "x",
                  "type": "int",
                  "mutable": false,
                  "parameter": false,
                  "from": "class point",
                  "word": {
                    "kind": "immediate",
                    "why": "int"
                  },
                  "range": {"line": 48, "column": 4, "end_line": 48, "end_column": 13}
                },
                {
                  "name": "name",
                  "type": "string",
                  "mutable": false,
                  "parameter": false,
                  "from": "class point",
                  "word": {
                    "kind": "pointer",
                    "tag": 252,
                    "what": "string"
                  },
                  "range": {"line": 49, "column": 4, "end_line": 49, "end_column": 18}
                }
              ],
              "unknown": [],
              "range": {"line": 46, "column": 0, "end_line": 50, "end_column": 5}
            },
            {
              "name": "class labelled",
              "line": 52,
              "env_slot": false,
              "vars": [
                {
                  "name": "k",
                  "type": "int",
                  "mutable": false,
                  "parameter": true,
                  "from": "class labelled",
                  "word": {
                    "kind": "immediate",
                    "why": "int"
                  },
                  "range": null
                },
                {
                  "name": "s",
                  "type": "string",
                  "mutable": false,
                  "parameter": true,
                  "from": "class labelled",
                  "word": {
                    "kind": "pointer",
                    "tag": 252,
                    "what": "string"
                  },
                  "range": null
                },
                {
                  "name": "v",
                  "type": "int",
                  "mutable": false,
                  "parameter": false,
                  "from": "class labelled",
                  "word": {
                    "kind": "immediate",
                    "why": "int"
                  },
                  "range": {"line": 54, "column": 4, "end_line": 54, "end_column": 13}
                }
              ],
              "unknown": [],
              "range": {"line": 52, "column": 0, "end_line": 57, "end_column": 5}
            },
            {
              "name": "class point3",
              "line": 59,
              "env_slot": false,
              "vars": [
                {
                  "name": "z",
                  "type": "int",
                  "mutable": false,
                  "parameter": false,
                  "from": "class point3",
                  "word": {
                    "kind": "immediate",
                    "why": "int"
                  },
                  "range": {"line": 61, "column": 4, "end_line": 61, "end_column": 13}
                },
                {
                  "name": "w",
                  "type": "string",
                  "mutable": false,
                  "parameter": false,
                  "from": "class point3",
                  "word": {
                    "kind": "pointer",
                    "tag": 252,
                    "what": "string"
                  },
                  "range": {"line": 63, "column": 4, "end_line": 63, "end_column": 15}
                },
                {
                  "name": "x",
                  "type": "int",
                  "mutable": false,
                  "parameter": false,
                  "from": "point",
                  "word": {
                    "kind": "immediate",
                    "why": "int"
                  },
                  "range": {"line": 48, "column": 4, "end_line": 48, "end_column": 13}
                },
                {
                  "name": "name",
                  "type": "string",
                  "mutable": false,
                  "parameter": false,
                  "from": "point",
                  "word": {
                    "kind": "pointer",
                    "tag": 252,
                    "what": "string"
                  },
                  "range": {"line": 49, "column": 4, "end_line": 49, "end_column": 18}
                }
              ],
              "unknown": [],
              "range": {"line": 59, "column": 0, "end_line": 65, "end_column": 5}
            },
            {
              "name": "object",
              "line": 68,
              "env_slot": true,
              "vars": [
                {
                  "name": "a",
                  "type": "int",
                  "mutable": false,
                  "parameter": false,
                  "from": "object",
                  "word": {
                    "kind": "immediate",
                    "why": "int"
                  },
                  "range": {"line": 69, "column": 4, "end_line": 69, "end_column": 13}
                }
              ],
              "unknown": [],
              "range": {"line": 68, "column": 2, "end_line": 71, "end_column": 5}
            },
            {
              "name": "class c",
              "line": 75,
              "env_slot": true,
              "vars": [
                {
                  "name": "a",
                  "type": "int",
                  "mutable": false,
                  "parameter": false,
                  "from": "class c",
                  "word": {
                    "kind": "immediate",
                    "why": "int"
                  },
                  "range": {"line": 78, "column": 8, "end_line": 78, "end_column": 17}
                },
                {
                  "name": "x",
                  "type": "int",
                  "mutable": false,
                  "parameter": false,
                  "from": "point",
                  "word": {
                    "kind": "immediate",
                    "why": "int"
                  },
                  "range": {"line": 48, "column": 4, "end_line": 48, "end_column": 13}
                },
                {
                  "name": "name",
                  "type": "string",
                  "mutable": false,
                  "parameter": false,
                  "from": "point",
                  "word": {
                    "kind": "pointer",
                    "tag": 252,
                    "what": "string"
                  },
                  "range": {"line": 49, "column": 4, "end_line": 49, "end_column": 18}
                }
              ],
              "unknown": [],
              "range": {"line": 75, "column": 4, "end_line": 80, "end_column": 9}
            },
            {
              "name": "object",
              "line": 87,
              "env_slot": true,
              "vars": [
                {
                  "name": "a",
                  "type": "int",
                  "mutable": true,
                  "parameter": false,
                  "from": "object",
                  "word": {
                    "kind": "immediate",
                    "why": "int"
                  },
                  "range": {"line": 88, "column": 4, "end_line": 88, "end_column": 21}
                }
              ],
              "unknown": [],
              "range": {"line": 87, "column": 2, "end_line": 91, "end_column": 5}
            },
            {
              "name": "object",
              "line": 94,
              "env_slot": false,
              "vars": [],
              "unknown": [],
              "range": {"line": 94, "column": 2, "end_line": 97, "end_column": 5}
            }
          ]
        }
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
                  "value": 0,
                  "cost": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 1, "column": 9, "end_line": 1, "end_column": 10}
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
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": {"line": 1, "column": 18, "end_line": 1, "end_column": 21}
                    }
                  ],
                  "cost": {
                    "words": [2],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 1, "column": 11, "end_line": 1, "end_column": 21}
              },
              {
                "name": "C",
                "shape": {
                  "kind": "immediate",
                  "value": 1,
                  "cost": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 1, "column": 22, "end_line": 1, "end_column": 25}
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
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [
                          {
                            "what": "string",
                            "per_node": null
                          }
                        ],
                        "nodes": false
                      },
                      "range": {"line": 1, "column": 33, "end_line": 1, "end_column": 39}
                    }
                  ],
                  "cost": {
                    "words": [2],
                    "range": false,
                    "not_counted": [
                      {
                        "what": "string",
                        "per_node": null
                      }
                    ],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 1, "column": 26, "end_line": 1, "end_column": 39}
              }
            ],
            "notes": [],
            "range": {"line": 1, "column": 0, "end_line": 1, "end_column": 39}
          },
          {
            "name": "nested",
            "params": "",
            "keyword": "type",
            "line": 2,
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
                      },
                      "owns": {
                        "words": [3],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": {"line": 2, "column": 20, "end_line": 2, "end_column": 29}
                    }
                  ],
                  "cost": {
                    "words": [5],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 2, "column": 14, "end_line": 2, "end_column": 30}
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
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": {"line": 2, "column": 39, "end_line": 2, "end_column": 42}
                    },
                    {
                      "kind": "arg",
                      "type": "int",
                      "mutable": false,
                      "word": {
                        "kind": "immediate",
                        "why": "int"
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": {"line": 2, "column": 45, "end_line": 2, "end_column": 48}
                    }
                  ],
                  "cost": {
                    "words": [3],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 2, "column": 31, "end_line": 2, "end_column": 48}
              }
            ],
            "notes": [],
            "range": {"line": 2, "column": 0, "end_line": 2, "end_column": 48}
          },
          {
            "name": "tree",
            "params": "'a",
            "keyword": "type",
            "line": 3,
            "kind": "variant",
            "cases": [
              {
                "name": "Leaf",
                "shape": {
                  "kind": "immediate",
                  "value": 0,
                  "cost": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 3, "column": 15, "end_line": 3, "end_column": 19}
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
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [],
                        "nodes": true
                      },
                      "range": {"line": 3, "column": 30, "end_line": 3, "end_column": 37}
                    },
                    {
                      "kind": "arg",
                      "type": "'a",
                      "mutable": false,
                      "word": {
                        "kind": "any",
                        "why": "type variable 'a"
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [
                          {
                            "what": "'a",
                            "per_node": null
                          }
                        ],
                        "nodes": false
                      },
                      "range": {"line": 3, "column": 40, "end_line": 3, "end_column": 42}
                    },
                    {
                      "kind": "arg",
                      "type": "'a tree",
                      "mutable": false,
                      "word": {
                        "kind": "any",
                        "why": "tree"
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [],
                        "nodes": true
                      },
                      "range": {"line": 3, "column": 45, "end_line": 3, "end_column": 52}
                    }
                  ],
                  "cost": {
                    "words": [4],
                    "range": false,
                    "not_counted": [
                      {
                        "what": "'a",
                        "per_node": null
                      }
                    ],
                    "nodes": true
                  }
                },
                "notes": [],
                "range": {"line": 3, "column": 20, "end_line": 3, "end_column": 52}
              }
            ],
            "notes": [],
            "range": {"line": 3, "column": 0, "end_line": 3, "end_column": 52}
          },
          {
            "name": "empty",
            "params": "",
            "keyword": "type",
            "line": 4,
            "kind": "variant",
            "cases": [],
            "notes": [],
            "range": {"line": 4, "column": 0, "end_line": 4, "end_column": 14}
          },
          {
            "name": "expr",
            "params": "_",
            "keyword": "type",
            "line": 6,
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
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": {"line": 7, "column": 10, "end_line": 7, "end_column": 13}
                    }
                  ],
                  "cost": {
                    "words": [2],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 7, "column": 2, "end_line": 7, "end_column": 25}
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
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [],
                        "nodes": false
                      },
                      "range": {"line": 8, "column": 11, "end_line": 8, "end_column": 15}
                    }
                  ],
                  "cost": {
                    "words": [2],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 8, "column": 2, "end_line": 8, "end_column": 28}
              },
              {
                "name": "Hide",
                "shape": {
                  "kind": "block",
                  "tag": 2,
                  "size": 2,
                  "fields": [
                    {
                      "kind": "arg",
                      "type": "'a",
                      "mutable": false,
                      "word": {
                        "kind": "any",
                        "why": "type variable 'a"
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [
                          {
                            "what": "'a",
                            "per_node": null
                          }
                        ],
                        "nodes": false
                      },
                      "range": {"line": 9, "column": 11, "end_line": 9, "end_column": 13}
                    },
                    {
                      "kind": "arg",
                      "type": "'a -> string",
                      "mutable": false,
                      "word": {
                        "kind": "pointer",
                        "tag": null,
                        "what": "closure, Closure_tag 247 or Infix_tag 249"
                      },
                      "owns": {
                        "words": [0],
                        "range": false,
                        "not_counted": [
                          {
                            "what": "closure",
                            "per_node": null
                          }
                        ],
                        "nodes": false
                      },
                      "range": {"line": 9, "column": 17, "end_line": 9, "end_column": 29}
                    }
                  ],
                  "cost": {
                    "words": [3],
                    "range": false,
                    "not_counted": [
                      {
                        "what": "'a",
                        "per_node": null
                      },
                      {
                        "what": "closure",
                        "per_node": null
                      }
                    ],
                    "nodes": false
                  }
                },
                "notes": [
                  "existential 'a: stored as uniform values"
                ],
                "range": {"line": 9, "column": 2, "end_line": 9, "end_column": 45}
              },
              {
                "name": "Unit",
                "shape": {
                  "kind": "immediate",
                  "value": 0,
                  "cost": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  }
                },
                "notes": [],
                "range": {"line": 10, "column": 2, "end_line": 10, "end_column": 20}
              }
            ],
            "notes": [
              "GADT: type indices are erased, so the constructors are numbered as in an ordinary variant"
            ],
            "range": {"line": 6, "column": 0, "end_line": 10, "end_column": 20}
          }
        ],
        "packages": [],
        "labels": [],
        "values": {
          "closures": [
            {
              "backend": "native code",
              "config": "Closure, without flambda",
              "closures": []
            }
          ],
          "lazy": [],
          "objects": []
        }
      }
    ],
    "collisions": []
  }
  ### cases/interface.mli
  {
    "word_size": 64,
    "units": [
      {
        "file": "cases/interface.mli",
        "unit": "Interface",
        "types": [
          {
            "name": "t",
            "params": "",
            "keyword": "type",
            "line": 2,
            "kind": "abstract",
            "word": {
              "kind": "any",
              "why": "abstract type"
            },
            "notes": [],
            "range": {"line": 2, "column": 0, "end_line": 2, "end_column": 6}
          },
          {
            "name": "small",
            "params": "",
            "keyword": "type",
            "line": 3,
            "kind": "abstract",
            "word": {
              "kind": "immediate",
              "why": "[@@immediate]"
            },
            "notes": [],
            "range": {"line": 3, "column": 0, "end_line": 3, "end_column": 24}
          },
          {
            "name": "id",
            "params": "",
            "keyword": "type",
            "line": 4,
            "kind": "alias",
            "word": {
              "kind": "immediate",
              "why": "int"
            },
            "notes": [],
            "range": {"line": 4, "column": 0, "end_line": 4, "end_column": 21}
          },
          {
            "name": "pos",
            "params": "",
            "keyword": "type",
            "line": 5,
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
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  },
                  "range": {"line": 5, "column": 21, "end_line": 5, "end_column": 31}
                },
                {
                  "kind": "label",
                  "name": "y",
                  "type": "float",
                  "mutable": false,
                  "word": {
                    "kind": "double"
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  },
                  "range": {"line": 5, "column": 32, "end_line": 5, "end_column": 41}
                }
              ],
              "cost": {
                "words": [3],
                "range": false,
                "not_counted": [],
                "nodes": false
              }
            },
            "notes": [],
            "range": {"line": 5, "column": 0, "end_line": 5, "end_column": 43}
          },
          {
            "name": "pair",
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
                  "name": "a",
                  "type": "t",
                  "mutable": false,
                  "word": {
                    "kind": "any",
                    "why": "abstract type t"
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [
                      {
                        "what": "abstract type t",
                        "per_node": null
                      }
                    ],
                    "nodes": false
                  },
                  "range": {"line": 6, "column": 14, "end_line": 6, "end_column": 20}
                },
                {
                  "kind": "label",
                  "name": "b",
                  "type": "small",
                  "mutable": false,
                  "word": {
                    "kind": "immediate",
                    "why": "small [@@immediate]"
                  },
                  "owns": {
                    "words": [0],
                    "range": false,
                    "not_counted": [],
                    "nodes": false
                  },
                  "range": {"line": 6, "column": 21, "end_line": 6, "end_column": 30}
                }
              ],
              "cost": {
                "words": [3],
                "range": false,
                "not_counted": [
                  {
                    "what": "abstract type t",
                    "per_node": null
                  }
                ],
                "nodes": false
              }
            },
            "notes": [],
            "range": {"line": 6, "column": 0, "end_line": 6, "end_column": 32}
          }
        ],
        "packages": [
          {
            "name": "CODEC",
            "line": 15,
            "size": 2,
            "fields": [
              {
                "index": 0,
                "item": "value",
                "name": "encode",
                "word": {
                  "kind": "pointer",
                  "tag": null,
                  "what": "closure, Closure_tag 247 or Infix_tag 249"
                },
                "range": {"line": 11, "column": 2, "end_line": 11, "end_column": 26}
              },
              {
                "index": 1,
                "item": "value",
                "name": "default",
                "word": {
                  "kind": "any",
                  "why": "abstract type v"
                },
                "range": {"line": 12, "column": 2, "end_line": 12, "end_column": 17}
              }
            ],
            "no_field": [
              "type v"
            ],
            "range": {"line": 8, "column": 0, "end_line": 13, "end_column": 3}
          }
        ],
        "labels": []
      }
    ],
    "collisions": []
  }
