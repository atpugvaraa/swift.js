'use client';
import { useState } from 'react';

import { Button, VStack } from '@swiftuijs/ui';

export const ToggleView = () => {
  const [isOn, setIsOn] = useState(false);

  return (
    <VStack alignment={"center"}>
<Button onClick={() => {
    isOn.toggle();
}}>
{"Toggle"}
</Button>
    isOn ? /* unknown: If-expression then branch not yet lowered */ : /* unknown: If-expression else branch not yet lowered */;
</VStack>
  );
}
