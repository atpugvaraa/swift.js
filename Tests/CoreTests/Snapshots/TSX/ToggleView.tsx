'use client';
import { useState } from 'react';

import { Button, Text, VStack } from '@swiftuijs/ui';

export const ToggleView = () => {
  const [isOn, setIsOn] = useState(false);

  return (
    <VStack alignment={"center"}>
{isOn ? <Text style={{ color: "var(--sw-color-green)" }}>
{"It is ON"}
</Text> : <Text style={{ color: "var(--sw-color-red)" }}>
{"It is OFF"}
</Text>}
<Button onClick={() => {
    setIsOn((isOn) => !isOn);
}}>
{"Toggle"}
</Button>
</VStack>
  );
}
