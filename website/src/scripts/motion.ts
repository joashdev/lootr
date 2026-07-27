import { animate, stagger } from 'animejs';

const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

if (!reducedMotion) {
  animate('.hero-animate', {
    opacity: [0, 1],
    y: [24, 0],
    duration: 900,
    delay: stagger(90),
    ease: 'outExpo',
  });

  animate('.floating-stat', {
    opacity: [0, 1],
    scale: [0.92, 1],
    duration: 700,
    delay: stagger(120, { start: 650 }),
    ease: 'outBack(1.4)',
  });

  const observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue;

        const section = entry.target;
        animate(section, {
          opacity: [0, 1],
          y: [32, 0],
          duration: 800,
          ease: 'outExpo',
        });

        const children = section.querySelectorAll(
          '.step-card, .feature-card, .mini-proof-grid article, .path-node, .path-line',
        );

        if (children.length) {
          animate(children, {
            opacity: [0, 1],
            y: [18, 0],
            duration: 650,
            delay: stagger(80),
            ease: 'outQuad',
          });
        }

        observer.unobserve(section);
      }
    },
    { threshold: 0.14 },
  );

  document.querySelectorAll<HTMLElement>('[data-reveal]').forEach((section) => {
    section.style.opacity = '0';
    observer.observe(section);
  });
}

const demoImage = document.querySelector<HTMLImageElement>('#demo-image');
const tabs = document.querySelectorAll<HTMLButtonElement>('.demo-tab');

tabs.forEach((tab) => {
  tab.addEventListener('click', () => {
    if (!demoImage || tab.classList.contains('is-active')) return;

    tabs.forEach((item) => {
      const active = item === tab;
      item.classList.toggle('is-active', active);
      item.setAttribute('aria-selected', String(active));
    });

    const nextSrc = tab.dataset.demo;
    const nextLabel = tab.dataset.label;
    if (!nextSrc) return;

    const swapImage = () => {
      demoImage.src = nextSrc;
      demoImage.alt = nextLabel ?? 'Lootr app preview';

      if (!reducedMotion) {
        animate(demoImage, {
          opacity: [0, 1],
          scale: [0.985, 1],
          duration: 420,
          ease: 'outQuad',
        });
      }
    };

    if (reducedMotion) {
      swapImage();
      return;
    }

    animate(demoImage, {
      opacity: [1, 0],
      scale: [1, 0.985],
      duration: 180,
      ease: 'inQuad',
      onComplete: swapImage,
    });
  });
});
