import { visit } from 'unist-util-visit';

export function remarkMermaid() {
  return (tree: any) => {
    visit(tree, 'code', (node: any, index: any, parent: any) => {
      if (node.lang !== 'mermaid' || !parent || index === undefined) return;
      parent.children.splice(index, 1, {
        type: 'html',
        value: `<div class="mermaid">${node.value}</div>`,
      });
    });
  };
}
