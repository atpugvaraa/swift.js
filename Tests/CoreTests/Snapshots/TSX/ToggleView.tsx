'use client';
import { useState } from 'react';

import { Button, VStack } from '@swiftjs/runtime';

export const ToggleView = () => {
  const [isOn, setIsOn] = useState(false);

  return (
    <VStack>
<Button title={"Toggle"} onClick={() => {
    isOn.toggle();
}} />
    isOn ? /* unknown: If-expression then branch not yet lowered */ : /* unknown: If-expression else branch not yet lowered */;
</VStack>
  );
}
